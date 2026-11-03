"""The shared step scripts (step.sh, run.sh, archive.sh, and common.sh's helpers), run through step.sh as the manager
runs them (but not in a screen), on the toy pipeline in example_pipeline/ and the fakes in fake_bin/: a night goes
from staging to archived, one whose makeflow fails can be resumed, and steps refuse to run out of order."""
import subprocess
from pathlib import Path

import pytest
import toml

import manager as m
from support import OPS_DIR, fake_env, write_config

pytestmark = pytest.mark.skipif(subprocess.run(['which', 'rsync'], capture_output=True).returncode != 0,
                                reason='needs rsync')
JD = '2459861'


def step(step_name, config_path, jd=JD, **env):
    return subprocess.run(['bash', str(OPS_DIR / 'scripts' / 'step.sh'), step_name, jd],
                          env=fake_env(config_path, **env), capture_output=True, text=True)


def exit_code(config, step_name, jd=JD):
    return int((config.state_dir(jd) / f'{step_name}.exit').read_text().split()[0])


def files(folder):
    folder = Path(folder)
    return sorted(str(p.relative_to(folder)) for p in folder.rglob('*') if not p.is_dir())


def test_a_night_from_staging_to_archived(config_path):
    config = m.Config.load(config_path)
    night, makeflow, cold = Path(config.nights_root) / JD, config.makeflow_dir(JD), Path(config.cold_root) / f'{JD}_analysis'

    for name in ('stage', 'build', 'run'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr
        assert exit_code(config, name) == 0
    assert m.parse_makeflowlog(config.makeflow_log(JD, config.step('run'))).outcome == 'COMPLETED'
    assert len(list(makeflow.glob('zen.*.PROCESS.out'))) == 3
    assert m.derive_state(JD, m.read_markers(config.state_dir(JD), config.step_names), set(), config).status == 'review'

    # nothing after review runs before the night is approved
    result = step('prune', config_path)
    assert result.returncode != 0 and 'has not been approved' in result.stdout
    assert exit_code(config, 'prune') != 0  # recorded, so the TUI shows why
    (config.state_dir(JD) / 'approved').write_text('test\n')

    for name in ('prune', 'archive'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr
    assert m.derive_state(JD, m.read_markers(config.state_dir(JD), config.step_names), set(), config).status == 'done'

    assert files(night) == ['COLD_STORAGE_INFO.txt']
    assert not (Path(config.raw_root) / JD).exists()
    assert sorted(p.name for p in makeflow.glob('*.tar.gz')) == [
        'makeflow_logs.tar.gz', 'makeflow_outs.tar.gz', 'makeflow_wrappers.tar.gz']
    assert not list(makeflow.glob('wrapper*.sh'))
    archived = files(cold)
    assert 'makeflow/makeflow_logs.tar.gz' in archived and f'makeflow/pipeline_status_report_{JD}.txt' in archived

    # both deleting steps are safe to run again
    for name in ('prune', 'archive'):
        result = step(name, config_path)
        assert result.returncode == 0, result.stdout + result.stderr


def test_archive_moves_bundles_to_cold_storage(config_path):
    config = m.Config.load(config_path)
    for name in ('stage', 'build', 'run'):
        assert step(name, config_path).returncode == 0
    (config.state_dir(JD) / 'approved').write_text('test\n')
    assert step('prune', config_path).returncode == 0
    night = Path(config.nights_root) / JD
    (night / 'sub').mkdir()
    for bundle in (f'{JD}_THINGS.tar.gz', f'sub/{JD}_OTHERS.tar.gz'):
        (night / bundle).write_text('bundle')
        (night / f'{bundle}.contents.txt').write_text('a file\n')
    (night / 'final.uvh5').write_text('a final product')

    result = step('archive', config_path)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'Deleted 2 bundles' in result.stdout
    cold = Path(config.cold_root) / f'{JD}_analysis'
    assert {f'{JD}_THINGS.tar.gz', f'sub/{JD}_OTHERS.tar.gz', 'final.uvh5'} <= set(files(cold))
    assert files(night) == sorted(['COLD_STORAGE_INFO.txt', 'final.uvh5', f'{JD}_THINGS.tar.gz.contents.txt',
                                   f'sub/{JD}_OTHERS.tar.gz.contents.txt'])


def test_a_failed_makeflow_is_resumed(config_path):
    config = m.Config.load(config_path)
    for name in ('stage', 'build'):
        assert step(name, config_path).returncode == 0
    result = step('run', config_path, FAKE_FAIL_JDS=JD)
    assert result.returncode != 0 and '1 jobs failed' in result.stdout
    assert exit_code(config, 'run') != 0
    assert len(m.Manager(config).error_logs(JD)) == 1

    # rerunning run resumes the makeflow, and sets the old error log aside
    result = step('run', config_path, FAKE_FAIL_JDS=JD, MAX_JOBS='50')
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'makeflow_nrao.sh example.mf 50' in result.stdout
    assert m.Manager(config).error_logs(JD) == []
    assert len(list((config.makeflow_dir(JD) / 'previous_errors' / 'attempt_1').glob('*.log.error'))) == 1
    log = (config.state_dir(JD) / 'logs' / 'run.log').read_text()
    assert log.count(f'===== run {JD}: started') == 2


def test_steps_wait_for_the_ones_before(config_path):
    config = m.Config.load(config_path)
    result = step('build', config_path)
    assert result.returncode != 0 and 'stage has not succeeded' in result.stdout
    assert not (Path(config.nights_root) / JD).exists()  # build.sh never ran


def test_an_unknown_step(config_path):
    result = step('nonesuch', config_path)
    assert result.returncode == 2 and 'unknown step' in result.stderr


def test_the_conda_environment_is_checked(config_path):
    result = subprocess.run(['bash', str(OPS_DIR / 'scripts' / 'step.sh'), 'stage', JD],
                            env=dict(fake_env(config_path), OPS_SKIP_CONDA='', CONDA_DEFAULT_ENV='base'),
                            capture_output=True, text=True)
    assert result.returncode != 0 and 'conda activate example_env' in result.stdout


def test_run_activates_the_tomls_conda_environment(config_path, tmp_path):
    config = m.Config.load(config_path)
    for name in ('stage', 'build'):
        assert step(name, config_path).returncode == 0
    # the run step's toml, with a source_script that sets up a stand-in for conda, as ~/.bashrc does at NRAO (and
    # has a line that fails, which mustn't matter)
    (tmp_path / 'bashrc').write_text('false\n'
                                     'conda () { [[ $1 == activate && $2 != broken ]] && export CONDA_DEFAULT_ENV=$2; }\n')
    cfg = toml.load(config.step('run').toml)
    cfg['Options']['source_script'] = str(tmp_path / 'bashrc')
    (tmp_path / 'toml').mkdir()
    toml_path = tmp_path / 'toml' / config.step('run').toml.name  # (the makeflow is named after it)

    def run():
        toml_path.write_text(toml.dumps(cfg))
        return subprocess.run(['bash', str(OPS_DIR / 'scripts' / 'run.sh'), JD, str(toml_path)],
                              env=dict(fake_env(config_path), OPS_SKIP_CONDA='', CONDA_DEFAULT_ENV='base'),
                              capture_output=True, text=True)

    result = run()
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'in conda environment example_env' in result.stdout
    cfg['Options']['conda_env'] = 'broken'
    result = run()
    assert result.returncode != 0 and 'could not conda activate broken' in result.stderr


def test_placeholders_refused(tmp_path):
    config_path = write_config(tmp_path)
    config_path.write_text(config_path.read_text().replace(str(tmp_path / 'nights'), 'FILL_ME_IN'))
    result = step('stage', config_path)
    assert result.returncode != 0 and 'set [paths] nights_root' in result.stderr
