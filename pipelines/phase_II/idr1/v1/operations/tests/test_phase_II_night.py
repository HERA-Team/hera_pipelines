"""Phase II's steps (stage.sh, build.sh, prune.sh here, with the shared run.sh and archive.sh), run through the
shared step.sh as the manager runs them (but not in a screen), against the fakes: a night goes from staging to
archived, with its products bundled, deleted, or kept as their retention in [DATA_PRODUCTS] says."""
import os
import re
import subprocess
import time
from pathlib import Path

import pytest

import manager as m
from conftest import PIPELINE_CONFIG, fake_env
from support import OPS_DIR

pytestmark = pytest.mark.skipif(subprocess.run(['which', 'rsync'], capture_output=True).returncode != 0,
                                reason='needs rsync')
JD = '2459861'
SB = 'single_baseline_files'


def step(step_name, config_path, jd=JD, **env):
    return subprocess.run(['bash', str(OPS_DIR / 'scripts' / 'step.sh'), step_name, jd],
                          env=fake_env(config_path, **env), capture_output=True, text=True)


def files(folder):
    folder = Path(folder)
    return sorted(str(p.relative_to(folder)) for p in folder.rglob('*') if not p.is_dir())


def run_and_approve(config_path):
    config = m.Config.load(config_path)
    for name in ('stage', 'build', 'run'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr
    (config.state_dir(JD) / 'approved').write_text('test\n')
    return config


def test_the_committed_config():
    config = m.Config.load(PIPELINE_CONFIG)
    assert config.step_names == ['stage', 'build', 'run', 'prune', 'archive']
    assert [step.script.parent for step in config.steps] == [PIPELINE_CONFIG.parent] * 2 + [m.SHARED_SCRIPTS] + \
        [PIPELINE_CONFIG.parent, m.SHARED_SCRIPTS]
    assert config.step('run').toml.name == 'phase_II_analysis.toml'


def test_a_night_from_staging_to_archived(config_path):
    config = m.Config.load(config_path)
    night, cold = Path(config.nights_root) / JD, Path(config.cold_root) / f'{JD}_analysis'

    for name in ('stage', 'build', 'run'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr
    assert len(list((Path(config.raw_root) / JD).glob('*.diff.uvh5'))) == 3  # an H6C night, so diffs too
    assert (config.makeflow_dir(JD) / 'provenance.txt').exists()
    # the "archive" products, each in its own bundle beside its files, and the rendered notebooks
    assert sorted(p.name for p in night.glob(f'{JD}_*.tar.gz')) == sorted(
        [f'{JD}_{name}.tar.gz' for name in ('AM', 'ANT_CLASS', 'SKY_CAL', 'DECOHERENCE', 'RED_AVG_ZSCORE',
                                            'FLAG_WATERFALL', 'ANTENNA_FLAGS', 'SMOOTH_CAL')]
        + [f'{JD}_sky_calibration_notebooks.tar.gz', f'{JD}_redundant_averaging_notebooks.tar.gz'])
    assert sorted(p.name for p in night.glob(f'{SB}/{JD}_*.tar.gz')) == sorted(
        [f'{JD}_{name}.tar.gz' for name in ('SKY_FILTERED_SNR', 'PI_DLYFILT_SNR', 'PI_FRF_SNR')]
        + [f'{JD}_{name}_notebooks.tar.gz' for name in ('sky_filtered_SNR', 'pI_DLYFILT_SNR', 'pI_FRF_SNR',
                                                        'wiener_inpaint')])  # named for each kind of notebook

    (config.state_dir(JD) / 'approved').write_text('test\n')
    for name in ('prune', 'archive'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr
        assert 'WARNING' not in result.stdout
        if name == 'prune':  # the raw data: their links in the night's folder, and their staged copies
            for raw in ('SUM', 'DIFF'):
                assert f'Deleted 3 {raw} files from {night}' in result.stdout
                assert f'Deleted 3 {raw} files from {Path(config.raw_root) / JD}' in result.stdout
    assert m.derive_state(JD, m.read_markers(config.state_dir(JD), config.step_names), set(), config).status == 'done'

    # on Lustre: the "keep" products, and the record of what went to cold storage
    left = [f for f in files(night) if not f.endswith('.contents.txt')]
    assert left == sorted(['COLD_STORAGE_INFO.txt', f'{JD}_aposteriori_flags.yaml', f'{SB}/corner_turn_map.yaml',
                           f'{SB}/zen.{JD}.flag_waterfall_sky_filtered.h5', f'{SB}/zen.{JD}.flag_waterfall_pI_dlyfilt.h5',
                           f'{SB}/zen.{JD}.flag_waterfall_pI_FRF.h5', f'{SB}/zen.{JD}.3C_286.flag_waterfall_pI_FRF.h5',
                           f'{SB}/phased.{JD}.3C_286.fg_model.uvh5'] + [
        f'{SB}/zen.{JD}.baseline.{bl}.sum.{suffix}'
        for bl in ('0_4', '1_5') for suffix in ('inpaint_covariance.h5', 'inpainted.uvh5', 'where_inpainted.h5')])
    assert not (Path(config.raw_root) / JD).exists()

    # in cold storage: every bundle, a copy of the final products, and the makeflow folder
    archived = files(cold)
    assert len([f for f in archived if f.endswith('.tar.gz') and not f.startswith('makeflow/')]) == 17
    assert f'{SB}/zen.{JD}.baseline.0_4.sum.inpainted.uvh5' in archived
    assert 'makeflow/makeflow_logs.tar.gz' in archived and f'makeflow/pipeline_status_report_{JD}.txt' in archived
    tarred = subprocess.run(['tar', '-tzf', str(cold / SB / f'{JD}_PI_FRF_SNR.tar.gz')],
                            capture_output=True, text=True).stdout.split()
    assert tarred == [f'{SB}/zen.{JD}.baseline.{bl}.sum.pI_FRF_SNR.uvh5' for bl in ('0_4', '1_5')]

    # both deleting steps are safe to run again
    for name in ('prune', 'archive'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr
    assert [f for f in files(night) if not f.endswith('.contents.txt')] == left


def test_a_status_report_cut_short(config_path):
    config = run_and_approve(config_path)
    makeflow_dir, report = config.makeflow_dir(JD), f'pipeline_status_report_{JD}.txt'
    result = step('prune', config_path, FAKE_STATUS_FAILS='1')
    assert result.returncode != 0
    assert not (makeflow_dir / report).exists()  # so a rerun writes it again,
    assert not (makeflow_dir / 'makeflow_logs.tar.gz').exists()  # from the logs it needs
    result = step('prune', config_path)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'end of the fake report' in (makeflow_dir / report).read_text()
    assert not (makeflow_dir / f'{report}.tmp').exists()


NO_DIFFS = '2460100'
RTP_CSVS = [f'zen.{NO_DIFFS}.{decimal}.sum.rtp_ant_class.csv' for decimal in ('12345', '13456', '14567')]


def test_a_night_without_diffs(config_path):
    config = m.Config.load(config_path)
    for name in ('stage', 'build'):
        result = step(name, config_path, jd=NO_DIFFS)
        assert result.returncode == 0, result.stdout + result.stderr
    raw = Path(config.raw_root) / NO_DIFFS
    assert not list(raw.glob('*.diff.uvh5'))
    assert sorted(p.name for p in raw.glob('*.csv')) == RTP_CSVS  # the librarian had them as they are
    assert sorted(p.name for p in (Path(config.nights_root) / NO_DIFFS).glob('*.csv')) == RTP_CSVS


def test_rtp_ant_class_from_rtps_tarball(config_path):
    config = m.Config.load(config_path)
    result = step('stage', config_path, jd=NO_DIFFS, FAKE_UNSTAGED=' '.join(RTP_CSVS))
    assert result.returncode == 0, result.stdout + result.stderr
    raw = Path(config.raw_root) / NO_DIFFS
    assert sorted(p.name for p in raw.iterdir() if 'csv' in p.name) == RTP_CSVS  # unpacked and renamed, tarball gone
    assert not [p for p in raw.iterdir() if p.is_dir()]


def test_no_rtp_ant_class(config_path):
    tarball = f'zen.{NO_DIFFS}.12345.sum.ant_class.csv.tar.gz'
    result = step('stage', config_path, jd=NO_DIFFS, FAKE_UNSTAGED=' '.join(RTP_CSVS + [tarball]))
    assert result.returncode != 0 and f'the librarian has no RTP antenna classifications for {NO_DIFFS}' in result.stdout


def test_a_sum_without_its_rtp_ant_class(config_path):
    missing = f'zen.{NO_DIFFS}.13456.sum.ant_class.csv'  # from RTP's tarball
    result = step('stage', config_path, jd=NO_DIFFS, FAKE_UNSTAGED=' '.join(RTP_CSVS + [missing]))
    assert result.returncode == 0 and "WARNING: that's 2 RTP antenna classifications for 3 sum files" in result.stdout
    result = step('build', config_path, jd=NO_DIFFS)
    assert result.returncode != 0
    assert f'zen.{NO_DIFFS}.13456.sum.uvh5 has no RTP antenna classification' in result.stdout


def exclude(config_path, *lines):
    (Path(config_path).parent / 'excluded_files.txt').write_text(''.join(f'{line}\n' for line in lines))


def test_the_committed_exclusions():
    queued = m.read_queue(PIPELINE_CONFIG.parent / 'nights.txt')
    for line in (PIPELINE_CONFIG.parent / 'excluded_files.txt').read_text().splitlines():
        entry = line.split('#')[0].split()
        if entry:
            jd, *decimals = entry
            assert jd in queued and decimals and all(re.fullmatch(r'\d{5}', d) for d in decimals), line


def test_build_leaves_out_excluded_files(config_path):
    config = m.Config.load(config_path)
    exclude(config_path, '# a comment', f'{JD}  13456 14567  # too many times', '2459999  12345  # another night')
    for name in ('stage', 'build'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr
    assert files(Path(config.nights_root) / JD) == [f'zen.{JD}.12345.diff.uvh5', f'zen.{JD}.12345.sum.uvh5']
    assert '13456' not in (config.makeflow_dir(JD) / 'phase_II_analysis.mf').read_text()
    provenance = (config.makeflow_dir(JD) / 'provenance.txt').read_text()
    assert f'zen.{JD}.13456: too many times' in provenance and f'zen.{JD}.14567: too many times' in provenance


def test_leaving_out_a_file_after_building(config_path):
    config = m.Config.load(config_path)
    for name in ('stage', 'build'):
        assert step(name, config_path).returncode == 0
    night = Path(config.nights_root) / JD
    made = night / f'zen.{JD}.13456.sum.smooth.calfits'
    made.write_text('made before the file was left out')
    exclude(config_path, f'{JD}  13456  # found to be bad')
    result = step('build', config_path)
    assert result.returncode != 0 and f'has files made from zen.{JD}.13456' in result.stdout
    made.unlink()
    result = step('build', config_path)
    assert result.returncode == 0, result.stdout + result.stderr
    assert not list(night.glob(f'zen.{JD}.13456.*'))  # its links from the first build are gone
    assert len(list(night.glob('*.uvh5'))) == 4


def test_a_sum_without_its_diff(config_path):
    result = step('stage', config_path, FAKE_UNSTAGED=f'zen.{JD}.12345.diff.uvh5')
    assert result.returncode == 0 and "WARNING: that's 2 diff files for 3 sum files" in result.stdout
    result = step('build', config_path)
    assert result.returncode != 0 and f'zen.{JD}.12345.sum.uvh5 has no diff' in result.stdout
    exclude(config_path, f'{JD}  12345  # no diff')
    result = step('build', config_path)
    assert result.returncode == 0, result.stdout + result.stderr


@pytest.mark.parametrize('line, error', [(f'{JD}  12345 1234  # a typo', 'should give a JD and the decimals'),
                                         (f'{JD}  # no decimals', 'should give a JD and the decimals'),
                                         (f'zen.{JD}.12345', 'should give a JD and the decimals'),
                                         (f'{JD}  99999', f'has no zen.{JD}.99999.sum.uvh5')])
def test_bad_exclusions(config_path, line, error):
    assert step('stage', config_path).returncode == 0
    exclude(config_path, line)
    result = step('build', config_path)
    assert result.returncode != 0 and error in result.stdout


def test_archive_needs_room_in_cold_storage(config_path):
    text = Path(config_path).read_text().replace('cold_min_free_tb = 0.0', 'cold_min_free_tb = 1e9')
    Path(config_path).write_text(text)
    config = run_and_approve(config_path)
    assert step('prune', config_path).returncode == 0
    result = step('archive', config_path)
    assert result.returncode != 0 and 'cold_min_free_tb' in result.stdout
    assert not (Path(config.cold_root) / f'{JD}_analysis').exists()


def test_prune_keeps_files_changed_since_bundling(config_path):
    config = run_and_approve(config_path)
    changed = Path(config.nights_root) / JD / f'zen.{JD}.12345.sum.smooth.calfits'
    os.utime(changed, (time.time() + 60, time.time() + 60))  # as if a job rewrote it after CLEANUP
    result = step('prune', config_path)
    assert result.returncode != 0 and 'has changed since' in result.stdout
    assert changed.exists()


def test_prune_needs_the_cleanup_job(config_path):
    config = run_and_approve(config_path)
    for out in config.makeflow_dir(JD).glob('*.CLEANUP.out'):
        out.unlink()
    result = step('prune', config_path)
    assert result.returncode != 0 and 'CLEANUP job never finished' in result.stdout
    assert list((Path(config.nights_root) / JD).glob('*.smooth.calfits'))


def test_prune_warns_about_files_no_product_declares(config_path):
    config = run_and_approve(config_path)
    stray = Path(config.nights_root) / JD / SB / f'zen.{JD}.baseline.0_4.sum.mystery.h5'
    stray.write_text('?')
    result = step('prune', config_path)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "WARNING: 1 files here aren't in [DATA_PRODUCTS]" in result.stdout and stray.name in result.stdout
    assert stray.exists()
