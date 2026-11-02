"""task_scripts/data_products.py, on the real toml and on small made-up ones: every product in a night's folder says
what becomes of it, each one's files are found where they are, and no file belongs to two products."""
import re
import subprocess
import sys

import pytest

import data_products as dp
from conftest import PIPELINE_TOML, TASK_SCRIPTS

JD = '2459861'


@pytest.fixture(scope='module')
def products():
    return dp.load(PIPELINE_TOML)


def test_every_product_in_the_night_has_a_retention(products):
    dp.check(products)
    retained = {name: spec['retention'] for name, spec in products.items() if dp.in_night(spec)}
    assert {name for name, retention in retained.items() if retention == 'delete'} == {
        'SUM', 'DIFF', 'RTP_ANT_CLASS', 'RED_AVG', 'SINGLE_BASELINE'}  # the raw data are never kept
    assert retained['INPAINTED'] == 'keep' and retained['SKY_CAL'] == 'archive'
    assert 'retention' not in products['SKY_MODEL']


def test_globs(products):
    assert dp.night_glob(products['SKY_CAL'], JD) == f'zen.{JD}.?????.sum.sky.calfits'
    assert dp.night_glob(products['INPAINTED'], JD) == f'single_baseline_files/zen.{JD}.baseline.*_*.sum.inpainted.uvh5'
    assert dp.night_glob(products['SOURCE_MODELS'], JD) == f'single_baseline_files/phased.{JD}.*.*.uvh5'
    assert dp.night_glob(products['APOSTERIORI_YAML'], JD) == f'{JD}_aposteriori_flags.yaml'
    assert dp.night_glob(products['SUM'], JD) == f'zen.{JD}.?????.sum.uvh5'  # an input linked into the night
    assert dp.night_glob(products['SOURCE_CATALOG'], JD) is None              # an input from elsewhere


def an_example_file(pattern):
    """A file name the glob matches."""
    return pattern.replace('?????', '12345').replace('*', 'x1')


def test_no_file_is_two_products(products):
    """A made-up file for each product is found as that product only."""
    globs = {name: dp.night_glob(spec, JD) for name, spec in products.items()}
    for name, pattern in globs.items():
        if pattern:
            claimed = [other for other, other_pattern in globs.items()
                       if other_pattern and dp.matches(an_example_file(pattern), other_pattern)]
            assert claimed == [name], an_example_file(pattern)


@pytest.mark.parametrize('spec, complaint', [
    ({'produced_by': 'A', 'suffix': 'sum.x.h5'}, 'retention = None'),
    ({'produced_by': 'A', 'suffix': 'sum.x.h5', 'retention': 'archived'}, "retention = 'archived'"),
    ({'produced_by': 'A', 'retention': 'keep'}, 'neither a filename nor a suffix'),
    ({'consumed_by': ['A'], 'suffix': 'sum.x.h5'}, 'retention = None'),  # an input linked into the night's folder
    ({'consumed_by': ['A'], 'suffix': 'sum.x.h5', 'retention': 'archive'}, 'cannot be archived'),
    ({'consumed_by': ['A'], 'filename': '/elsewhere/x.h5', 'retention': 'keep'}, 'takes no retention'),
])
def test_problems(spec, complaint):
    with pytest.raises(ValueError, match=re.escape(complaint)):
        dp.check({'X': spec})


def test_files_and_clashes(tmp_path):
    (tmp_path / 'sub').mkdir()
    for name in (f'zen.{JD}.12345.sum.a.h5', f'zen.{JD}.23456.sum.a.h5', f'zen.{JD}.12345.sum.b.h5',
                 f'sub/zen.{JD}.baseline.0_4.sum.a.h5', 'stray.txt', f'sub/{JD}_A.tar.gz'):
        (tmp_path / name).write_text('')
    products = {'A': {'produced_by': 'X', 'suffix': 'sum.a.h5', 'retention': 'archive'},
                'B': {'produced_by': 'X', 'suffix': 'sum.b.h5', 'retention': 'delete'},
                'A_BL': {'produced_by': 'X', 'suffix': 'sum.a.h5', 'retention': 'keep',
                         'filename': 'sub/zen.{JD}.baseline.{ant1}_{ant2}.sum.a.h5'}}
    assert dp.files(products, JD, 'A', tmp_path) == [f'zen.{JD}.12345.sum.a.h5', f'zen.{JD}.23456.sum.a.h5']
    assert dp.files(products, JD, 'A_BL', tmp_path) == [f'sub/zen.{JD}.baseline.0_4.sum.a.h5']
    assert dp.undeclared(products, JD, [f'sub/{JD}_*.tar.gz'], tmp_path) == ['stray.txt']
    products['ALL'] = {'produced_by': 'X', 'filename': 'zen.{JD}.{decimal}.sum.{what}.h5', 'retention': 'keep'}
    with pytest.raises(ValueError, match='would be both A'):
        dp.files(products, JD, 'A', tmp_path)


def test_the_command_line(tmp_path):
    result = subprocess.run([sys.executable, str(TASK_SCRIPTS / 'data_products.py'), 'names', str(PIPELINE_TOML),
                             'delete'], capture_output=True, text=True)
    assert result.stdout.split() == ['SUM', 'DIFF', 'RTP_ANT_CLASS', 'RED_AVG', 'SINGLE_BASELINE']
    bad = tmp_path / 'bad.toml'
    bad.write_text('[DATA_PRODUCTS.X]\nproduced_by = "A"\nsuffix = "sum.x.h5"\n')
    result = subprocess.run([sys.executable, str(TASK_SCRIPTS / 'data_products.py'), 'names', str(bad), 'keep'],
                            capture_output=True, text=True)
    assert result.returncode == 1 and 'X has retention = None' in result.stderr
