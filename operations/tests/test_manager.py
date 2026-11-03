"""The manager's logic: the config, markers -> state, the scheduler, the makeflow log parser, the queue, and its
actions. These use the toy pipeline in example_pipeline/ (stage, build, run, review, prune, archive)."""
import dataclasses
import datetime
import os
import re

import pytest
import toml

import manager as m
from support import EXAMPLE_CONFIG, FakeScreens, write_config

T0 = datetime.datetime(2026, 10, 28, 12, 0, 0)


def minutes(n):
    return T0 + datetime.timedelta(minutes=n)


@pytest.fixture
def config(config_path):
    return m.Config.load(config_path)


def markers(approved=None, hold=None, **steps):
    """Markers with the given StepRecords (by step name); every other step not begun."""
    names = ('stage', 'build', 'run', 'prune', 'archive')
    return m.Markers(steps={step: steps.get(step, m.StepRecord()) for step in names}, approved=approved, hold=hold)


def done(start, host='here'):
    return m.StepRecord(started=minutes(start), host=host, exit_code=0, ended=minutes(start + 1))


def state(marks, alive=(), at=minutes(100), config=None):
    return m.derive_state('2459861', marks, set(alive), config, host='here', at=at)


class TestConfig:
    def test_the_example(self, config):
        assert config.step_names == ['stage', 'build', 'run', 'prune', 'archive']
        assert config.step('stage').script == EXAMPLE_CONFIG.parent / 'stage.sh'  # beside the config
        assert config.step('run').script == m.SHARED_SCRIPTS / 'run.sh'          # or else a shared one
        assert config.step('run').makeflow and config.step('run').limit == 'running'
        assert config.step('build').toml == EXAMPLE_CONFIG.parent / 'example.toml'
        assert [step.after_review for step in config.steps] == [False, False, False, True, True]
        assert config.limits == {'staging': 1, 'running': 2} and config.max_in_flight == 3
        assert config.nights_file == config.path.parent / 'nights.txt'

    @pytest.mark.parametrize('change, complaint', [
        (lambda c: c['workflow'].update(steps=['review', 'stage']), 'first or last'),
        (lambda c: c['workflow'].update(steps=['stage', 'stage']), 'more than once'),
        (lambda c: c['workflow'].update(steps=['stage', 'Run']), 'lowercase'),
        (lambda c: c['workflow'].update(steps=['stage', 'nonesuch']), 'no script for step nonesuch'),
        (lambda c: c['steps']['run'].update(limit='gpus'), '[limits] gpus is not set'),
        (lambda c: c['steps']['run'].update(retries=3), 'unknown settings: retries'),
        (lambda c: c['steps']['run'].pop('toml'), 'needs a toml'),
    ])
    def test_problems(self, tmp_path, change, complaint):
        cfg = toml.load(write_config(tmp_path))
        change(cfg)
        (tmp_path / 'config.toml').write_text(toml.dumps(cfg))
        with pytest.raises(ValueError, match=re.escape(complaint)):
            m.Config.load(tmp_path / 'config.toml')


@pytest.fixture
def two_makeflows(tmp_path):
    """A pipeline with two makeflows a night, as H6C's analysis and post-inpaint, sharing one limit on running ones."""
    cfg = toml.load(write_config(tmp_path))
    cfg['workflow']['steps'] = ['stage', 'build', 'run', 'build_post', 'run_post', 'review', 'prune', 'archive']
    run = cfg['steps']['run']
    cfg['steps']['build_post'] = dict(cfg['steps']['build'], toml=str(tmp_path / 'post.toml'))
    cfg['steps']['run_post'] = dict(run, toml=str(tmp_path / 'post.toml'))
    (tmp_path / 'config.toml').write_text(toml.dumps(cfg))
    return m.Config.load(tmp_path / 'config.toml')


class TestTwoMakeflows:
    def test_labels(self, two_makeflows):
        names = two_makeflows.step_names
        marks = m.Markers(steps={name: m.StepRecord() for name in names})
        for name in ('stage', 'build', 'run'):
            marks.steps[name] = done(0)
        s = m.derive_state('2459861', marks, set(), two_makeflows, host='here', at=minutes(100))
        assert (s.step, s.label) == ('build_post', 'ran')
        marks.steps['build_post'] = done(2)
        marks.steps['run_post'] = m.StepRecord(started=minutes(3), host='here')
        s = m.derive_state('2459861', marks, {'p2test_run_post_2459861'}, two_makeflows, host='here', at=minutes(100))
        assert (s.step, s.label) == ('run_post', 'run_post running')
        marks.steps['run_post'] = done(3)
        s = m.derive_state('2459861', marks, set(), two_makeflows, host='here', at=minutes(100))
        assert (s.step, s.status) == ('run_post', 'review')

    def test_they_share_a_limit(self, two_makeflows):  # running = 2
        nights = [m.NightState('1', 'run', 'active'), m.NightState('2', 'run_post', 'active'),
                  m.NightState('3', 'run_post', 'waiting'), m.NightState('4', 'build_post', 'waiting')]
        assert m.plan_actions(nights, two_makeflows, auto=True) == [('build_post', '4')]

    def test_progress_is_the_current_makeflows(self, two_makeflows, screens):
        manager = m.Manager(two_makeflows, screens)
        state_dir, makeflow_dir = two_makeflows.state_dir('2459861'), two_makeflows.makeflow_dir('2459861')
        state_dir.mkdir(parents=True)
        makeflow_dir.mkdir(parents=True)
        for name in ('stage', 'build', 'run', 'build_post'):
            (state_dir / f'{name}.started').write_text(f'{T0.isoformat()} here 1\n')
            (state_dir / f'{name}.exit').write_text(f'0 {T0.isoformat()}\n')
        (makeflow_dir / 'example.mf.makeflowlog').write_text(LOG + '1 1 2 1 0 0 10 0 0 10\n# COMPLETED 2\n')
        assert str(manager.night('2459861').progress) == '10/10'
        (state_dir / 'run_post.started').write_text(f'{T0.isoformat()} here 1\n')
        (makeflow_dir / 'post.mf.makeflowlog').write_text(LOG)
        assert str(manager.night('2459861').progress) == '1/10, 1 running'


class TestDeriveState:
    def test_queued(self, config):
        s = state(markers(), config=config)
        assert (s.step, s.status, s.label, s.in_flight) == ('stage', 'waiting', 'queued', False)

    def test_launched_and_starting(self, config):
        launched = m.StepRecord(launched=minutes(99.5))
        assert state(markers(stage=launched), config=config).status == 'active'

    def test_launched_but_never_started(self, config):
        launched = m.StepRecord(launched=minutes(90))
        assert state(markers(stage=launched), config=config).status == 'lost'
        # ...unless its screen is still there
        alive = {config.session_name('stage', '2459861')}
        assert state(markers(stage=launched), alive, config=config).status == 'active'

    def test_running(self, config):
        running = m.StepRecord(started=minutes(10), host='here')
        marks = markers(stage=done(0), build=done(2), run=running)
        alive = {config.session_name('run', '2459861')}
        s = state(marks, alive, config=config)
        assert (s.step, s.status, s.label) == ('run', 'active', 'running')
        assert state(marks, config=config).status == 'lost'  # its screen is gone

    def test_running_on_another_host(self, config):
        marks = markers(stage=done(0), build=m.StepRecord(started=minutes(10), host='elsewhere.nrao.edu'))
        assert state(marks, config=config).status == 'elsewhere'

    def test_failed(self, config):
        failed = m.StepRecord(started=minutes(10), host='here', exit_code=1, ended=minutes(20))
        s = state(markers(stage=done(0), build=done(2), run=failed), config=config)
        assert (s.step, s.status, s.label) == ('run', 'failed', 'run failed')

    def test_queued_by_hand(self, config):
        s = state(markers(stage=m.StepRecord(requested=minutes(5))), config=config)
        assert (s.status, s.requested, s.label, s.in_flight) == ('waiting', True, 'queued to stage', False)
        failed = m.StepRecord(started=minutes(10), host='here', exit_code=1, ended=minutes(20), requested=minutes(30))
        s = state(markers(stage=done(0), build=done(2), run=failed), config=config)
        assert (s.status, s.requested, s.label) == ('failed', True, 'queued to run again')

    def test_relaunched_after_failure(self, config):
        # the manager removes .exit and writes a newer .launched; the old .started is still there until step.sh runs
        rerun = m.StepRecord(launched=minutes(99.9), started=minutes(10), host='here')
        assert state(markers(stage=done(0), build=done(2), run=rerun), config=config).status == 'active'

    def test_review_then_approved_then_done(self, config):
        ran = dict(stage=done(0), build=done(2), run=done(4))
        s = state(markers(**ran), config=config)
        assert (s.step, s.status, s.label, s.in_flight) == ('run', 'review', 'review', True)
        s = state(markers(approved='yes', **ran), config=config)
        assert (s.step, s.status, s.label) == ('prune', 'waiting', 'approved')
        s = state(markers(approved='yes', prune=done(6), **ran), config=config)
        assert s.label == 'pruned'
        s = state(markers(approved='yes', prune=done(6), archive=done(8), **ran), config=config)
        assert (s.status, s.label, s.in_flight) == ('done', 'done', False)

    def test_held(self, config):
        s = state(markers(hold='looking at it', stage=done(0)), config=config)
        assert s.held and s.label == 'staged (held)'


def states(*specs):
    """NightStates from (jd, step, status) or (jd, step, status, held), for the example pipeline."""
    return [m.NightState(*spec, in_flight=not (spec[2] == 'done' or spec[1:3] == ('stage', 'waiting')))
            for spec in specs]


class TestPlanActions:
    def test_auto_off(self, config):  # no new night starts, but those under way carry on
        nights = states(('1', 'stage', 'waiting'), ('2', 'build', 'waiting'), ('3', 'prune', 'waiting'),
                        ('4', 'run', 'waiting', True))
        assert m.plan_actions(nights, config, auto=False) == [('build', '2'), ('prune', '3')]

    def test_ready_steps_start(self, config):
        nights = states(('1', 'build', 'waiting'), ('2', 'prune', 'waiting'), ('3', 'archive', 'waiting'))
        assert m.plan_actions(nights, config, auto=True) == [('build', '1'), ('prune', '2'), ('archive', '3')]

    def test_running_limit(self, config):  # running = 2
        nights = states(('1', 'run', 'active'), ('2', 'run', 'waiting'), ('3', 'run', 'waiting'))
        assert m.plan_actions(nights, config, auto=True) == [('run', '2')]

    def test_staging_limit(self, config):  # staging = 1
        nights = states(('1', 'stage', 'waiting'), ('2', 'stage', 'waiting'))
        assert m.plan_actions(nights, config, auto=True) == [('stage', '1')]
        nights = states(('0', 'stage', 'active'), ('1', 'stage', 'waiting'))
        assert m.plan_actions(nights, config, auto=True) == []

    def test_in_flight_limit(self, config):  # max_in_flight = 3; failed, lost, and held nights still hold space
        nights = states(('1', 'run', 'review'), ('2', 'run', 'failed'), ('3', 'build', 'lost', True),
                        ('4', 'stage', 'waiting'))
        assert m.plan_actions(nights, config, auto=True) == []
        nights = states(('1', 'archive', 'done'), ('2', 'run', 'review'), ('3', 'stage', 'waiting'))
        assert m.plan_actions(nights, config, auto=True) == [('stage', '3')]

    def test_disk_limit(self, config):
        config.min_free_tb = 10
        nights = states(('1', 'stage', 'waiting'), ('2', 'build', 'waiting'))
        assert m.plan_actions(nights, config, auto=True, free_tb=5) == [('build', '2')]
        assert m.plan_actions(nights, config, auto=True, free_tb=50) == [('stage', '1'), ('build', '2')]

    def test_never_retries_or_touches_held(self, config):
        nights = states(('1', 'run', 'failed'), ('2', 'build', 'lost'), ('3', 'build', 'waiting', True))
        assert m.plan_actions(nights, config, auto=True) == []
        nights[2] = dataclasses.replace(nights[2], requested=True)  # unless queued by hand
        assert m.plan_actions(nights, config, auto=False) == [('build', '3')]

    def test_queued_by_hand(self, config):  # staging = 1, max_in_flight = 3
        nights = states(('1', 'stage', 'waiting'), ('2', 'stage', 'waiting'), ('3', 'run', 'failed'),
                        ('4', 'build', 'waiting'))
        nights[1:3] = [dataclasses.replace(s, requested=True) for s in nights[1:3]]
        # first, and whether auto is on or not
        assert m.plan_actions(nights, config, auto=False) == [('stage', '2'), ('run', '3'), ('build', '4')]
        assert m.plan_actions(nights, config, auto=True) == [('stage', '2'), ('run', '3'), ('build', '4')]
        # but only once there's room in their limit
        nights.append(m.NightState('0', 'stage', 'active'))
        assert m.plan_actions(nights, config, auto=False) == [('run', '3'), ('build', '4')]

    def test_queued_by_hand_needs_no_room_in_flight(self, config):  # max_in_flight = 3
        nights = states(('1', 'run', 'review'), ('2', 'run', 'review'), ('3', 'run', 'review'), ('4', 'stage', 'waiting'),
                        ('5', 'stage', 'waiting'))
        nights[3] = dataclasses.replace(nights[3], requested=True)
        assert m.plan_actions(nights, config, auto=True) == [('stage', '4')]

    def test_skips_a_step_whose_screen_is_open(self, config):
        nights = states(('2459861', 'build', 'waiting'))
        assert m.plan_actions(nights, config, auto=True, live_sessions={'p2test_build_2459861'}) == []


LOG = """\
# NODE 0 zen.2459861.12345.sum.uvh5.FILE_SKY_CAL_NOTEBOOK.out
# STARTED 1761670000000000
1761670001000000 0 1 101 9 1 0 0 0 10
1761670002000000 0 2 101 9 0 1 0 0 10
1761670003000000 1 1 102 7 1 1 0 0 10
"""


class TestParseMakeflowlog:
    def test_running(self, tmp_path):
        (tmp_path / 'mf.makeflowlog').write_text(LOG)
        progress = m.parse_makeflowlog(tmp_path / 'mf.makeflowlog')
        assert (progress.running, progress.complete, progress.total, progress.outcome) == (1, 1, 10, 'STARTED')
        assert str(progress) == '1/10, 1 running'

    def test_failed(self, tmp_path):
        (tmp_path / 'mf.makeflowlog').write_text(LOG + '1761670004000000 1 3 102 7 0 1 1 0 10\n# FAILED 1761670005000000\n')
        progress = m.parse_makeflowlog(tmp_path / 'mf.makeflowlog')
        assert (progress.failed, progress.outcome, str(progress)) == (1, 'FAILED', '1/10, 1 failed')

    def test_completed_after_a_rerun(self, tmp_path):
        log = LOG + '# FAILED 1\n# STARTED 2\n1761670009000000 9 2 110 0 0 10 0 0 10\n# COMPLETED 3\n'
        (tmp_path / 'mf.makeflowlog').write_text(log)
        progress = m.parse_makeflowlog(tmp_path / 'mf.makeflowlog')
        assert (progress.complete, progress.total, progress.outcome) == (10, 10, 'COMPLETED')

    def test_reads_only_the_end(self, tmp_path):
        (tmp_path / 'mf.makeflowlog').write_text('x' * 100000 + '\n' + LOG)
        assert m.parse_makeflowlog(tmp_path / 'mf.makeflowlog', tail_bytes=200).total == 10

    def test_no_log(self, tmp_path):
        assert m.parse_makeflowlog(tmp_path / 'missing') is None


def test_queue(tmp_path):
    nights = tmp_path / 'nights.txt'
    nights.write_text('# header\n2459861\n2459862  # a note\n\n2459861\nnot a jd\n2459863')
    assert m.read_queue(nights) == ['2459861', '2459862', '2459863']
    assert m.add_to_queue(nights, ['2459862', '2459864', '2459864']) == ['2459864']
    assert m.read_queue(nights)[-1] == '2459864'
    with pytest.raises(ValueError):
        m.add_to_queue(nights, ['245986'])


def test_placeholders_stop_everything(tmp_path):
    manager = m.Manager(m.Config.load(EXAMPLE_CONFIG), FakeScreens())  # still full of FILL_ME_IN
    assert 'fill in [paths]' in manager.launch_problem()
    with pytest.raises(RuntimeError):
        manager.launch('stage', '2459861')
    with pytest.raises(RuntimeError):
        manager.auto = True
    assert manager.tick() == []


def test_required_host(tmp_path, screens):
    manager = m.Manager(m.Config.load(write_config(tmp_path, required_host='herapost-master')), screens)
    manager.host = 'login1'
    assert 'herapost-master' in manager.launch_problem()
    with pytest.raises(RuntimeError):
        manager.launch('stage', '2459861')


class TestManagerActions:
    @pytest.fixture
    def manager(self, config_path, screens):
        return m.Manager(m.Config.load(config_path), screens)

    def test_launch(self, manager, screens):
        manager.launch('stage', '2459861')
        name, command, env = screens.launched[0]
        assert name == 'p2test_stage_2459861'
        assert command[0] == 'bash' and command[1] == str(m.SHARED_SCRIPTS / 'step.sh')
        assert command[2:] == ['stage', '2459861']
        assert env['OPS_CONFIG'] == str(manager.config.path) and env['OPS_SHELL_ON_FAILURE'] == '1'
        assert manager.night('2459861').state.label == 'staging'
        with pytest.raises(RuntimeError, match='still open'):
            manager.launch('stage', '2459861')

    def test_launch_run_with_a_job_cap(self, manager, screens):
        manager.launch('run', '2459861', max_jobs=50)
        assert screens.launched[0][2]['MAX_JOBS'] == '50'

    def test_tick_launches_in_queue_order(self, manager, screens):
        m.add_to_queue(manager.config.nights_file, ['2459862', '2459861'])
        manager.auto = True
        assert manager.tick() == [('stage', '2459862')]
        assert [name for name, _, _ in screens.launched] == ['p2test_stage_2459862']
        assert manager.tick() == []  # still staging, and only one night may stage at once

    def test_launching_by_hand_queues_while_the_limit_is_full(self, manager, screens):
        assert manager.launch('stage', '2459861') == []
        assert manager.launch('stage', '2459862') == ['2459861']  # staging = 1
        assert [name for name, _, _ in screens.launched] == ['p2test_stage_2459861']
        assert manager.night('2459862').state.label == 'queued to stage'
        assert manager.tick() == []  # auto is off, and 2459861 is still staging
        self.finish(manager, screens, '2459861', 'stage')
        # auto is off, but 2459862 was queued by hand, and 2459861 is under way
        assert manager.tick() == [('stage', '2459862'), ('build', '2459861')]
        assert manager.night('2459862').state.label == 'staging'
        assert not list(manager.config.state_dir('2459862').glob('*.requested'))

    def test_a_night_started_by_hand_carries_on(self, manager, screens):  # with auto off
        manager.launch('stage', '2459861')
        for step, then in (('stage', 'build'), ('build', 'run')):
            self.finish(manager, screens, '2459861', step)
            assert manager.tick() == [(then, '2459861')]
        self.finish(manager, screens, '2459861', 'run')
        assert manager.tick() == [] and manager.night('2459861').state.status == 'review'
        manager.approve('2459861')
        assert manager.tick() == [('prune', '2459861')]
        self.finish(manager, screens, '2459861', 'prune')
        manager.hold('2459861')  # held, it waits for you
        assert manager.tick() == []
        assert manager.launch('archive', '2459861') == []

    def test_a_queued_makeflow_keeps_its_job_cap(self, manager, screens):  # running = 2
        for jd in ('2459861', '2459862', '2459863'):
            manager.config.state_dir(jd).mkdir(parents=True)
            self.finish(manager, screens, jd, 'stage')
            self.finish(manager, screens, jd, 'build')
        for jd in ('2459861', '2459862'):
            manager.launch('run', jd)
        assert manager.launch('run', '2459863', max_jobs=50) == ['2459861', '2459862']
        self.finish(manager, screens, '2459861', 'run')
        assert manager.tick() == [('run', '2459863')]
        assert screens.launched[-1][0] == 'p2test_run_2459863' and screens.launched[-1][2]['MAX_JOBS'] == '50'

    def test_unqueue_and_reset(self, manager):
        manager.launch('stage', '2459861')
        for take_back in (lambda: manager.unqueue('2459862'), lambda: manager.reset('2459862', 'stage')):
            manager.launch('stage', '2459862')
            assert manager.night('2459862').state.requested
            take_back()
            assert manager.night('2459862').state.label == 'queued'

    @staticmethod
    def finish(manager, screens, jd, step):
        """The step's screen has gone, and step.sh recorded that it succeeded."""
        screens.alive.discard(manager.config.session_name(step, jd))
        (manager.config.state_dir(jd) / f'{step}.started').write_text(f'{m.now().isoformat()} {manager.host} 1\n')
        (manager.config.state_dir(jd) / f'{step}.exit').write_text(f'0 {m.now().isoformat()}\n')

    def test_approve_only_in_review(self, manager):
        with pytest.raises(RuntimeError, match='not waiting for review'):
            manager.approve('2459861')
        state_dir = manager.config.state_dir('2459861')
        state_dir.mkdir(parents=True)
        for step in ('stage', 'build', 'run'):
            (state_dir / f'{step}.started').write_text(f'{T0.isoformat()} here 1\n')
            (state_dir / f'{step}.exit').write_text(f'0 {T0.isoformat()}\n')
        manager.approve('2459861', 'looks fine')
        assert 'looks fine' in (state_dir / 'approved').read_text()
        assert manager.night('2459861').state.label == 'approved'

    def test_prune_needs_approval(self, manager):
        with pytest.raises(RuntimeError, match='not been approved'):
            manager.launch('prune', '2459861')

    def test_reset(self, manager, screens):
        state_dir = manager.config.state_dir('2459861')
        state_dir.mkdir(parents=True)
        for step in ('stage', 'build', 'run'):
            (state_dir / f'{step}.started').write_text(f'{T0.isoformat()} here 1\n')
            (state_dir / f'{step}.exit').write_text(f'0 {T0.isoformat()}\n')
        (state_dir / 'approved').write_text('yes\n')
        manager.reset('2459861', 'run')
        assert sorted(p.name for p in state_dir.iterdir()) == ['build.exit', 'build.started', 'stage.exit', 'stage.started']
        screens.alive.add('p2test_build_2459861')
        with pytest.raises(RuntimeError, match='still open'):
            manager.reset('2459861', 'stage')

    def test_hold_and_abort(self, manager, screens):
        manager.hold('2459861', 'wait')
        assert manager.night('2459861').state.held
        manager.unhold('2459861')
        assert not manager.night('2459861').state.held
        with pytest.raises(RuntimeError, match='nothing to abort'):
            manager.abort('2459861')
        manager.launch('stage', '2459861')
        manager.abort('2459861')
        assert screens.interrupted == ['p2test_stage_2459861']

    def test_step_settings_refuse_out_of_order_or_unapproved(self, manager):
        settings = manager.step_settings('stage', '2459861')
        assert settings['script'] == EXAMPLE_CONFIG.parent / 'stage.sh' and settings['refusal'] == ''
        assert 'stage has not succeeded' in manager.step_settings('build', '2459861')['refusal']
        state_dir = manager.config.state_dir('2459861')
        state_dir.mkdir(parents=True)
        for step in ('stage', 'build', 'run'):
            (state_dir / f'{step}.started').write_text(f'{T0.isoformat()} here 1\n')
            (state_dir / f'{step}.exit').write_text(f'0 {T0.isoformat()}\n')
        assert 'not been approved' in manager.step_settings('prune', '2459861')['refusal']
        (state_dir / 'approved').write_text('yes\n')
        settings = manager.step_settings('prune', '2459861')
        assert settings['refusal'] == '' and settings['toml'] == EXAMPLE_CONFIG.parent / 'example.toml'
        assert 'prune has not succeeded' in manager.step_settings('archive', '2459861')['refusal']

    def test_nights_include_ones_dropped_from_the_queue(self, manager):
        m.add_to_queue(manager.config.nights_file, ['2459862'])
        manager.config.state_dir('2459861').mkdir(parents=True)
        assert manager.jds() == ['2459862', '2459861']

    def test_lock(self, config_path, manager):
        manager.take_lock()
        assert not manager.read_only
        other = m.Manager(m.Config.load(config_path), FakeScreens())
        manager.lock_file.write_text(f'{manager.host} {os.getppid()}\n')  # a live process that isn't this one
        other.take_lock()
        assert other.read_only and other.tick() == []
        manager.lock_file.write_text(f'{manager.host} 999999999\n')  # stale
        third = m.Manager(m.Config.load(config_path), FakeScreens())
        third.take_lock()
        assert not third.read_only
        third.release_lock()
        assert not manager.lock_file.exists()
