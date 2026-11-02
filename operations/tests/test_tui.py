"""The TUI, driven by Textual's test pilot against fake screens: its keys do what they say."""
import asyncio
import datetime

import pytest

pytest.importorskip('textual')

import manager as m  # noqa: E402
from tui import ManagerApp  # noqa: E402

JD = '2459861'


def finish(state_dir, *steps):
    state_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime(2026, 10, 28, 12).isoformat()
    for step in steps:
        (state_dir / f'{step}.started').write_text(f'{stamp} {m.short_host()} 1\n')
        (state_dir / f'{step}.exit').write_text(f'0 {stamp}\n')


def drive(manager, *keys):
    """Start the app, let it load, press the keys (a list means: type these characters), and let it settle."""
    async def go():
        app = ManagerApp(manager)
        async with app.run_test(size=(160, 40)) as pilot:
            await settle(app, pilot)
            for key in keys:
                await pilot.press(*key) if isinstance(key, list) else await pilot.press(key)
                await settle(app, pilot)
            return app
    return asyncio.run(go())


async def settle(app, pilot):
    for _ in range(3):
        await pilot.pause()
        await app.workers.wait_for_complete()
    await pilot.pause()


@pytest.fixture
def manager(config_path, screens):
    manager = m.Manager(m.Config.load(config_path), screens)
    m.add_to_queue(manager.config.nights_file, [JD])
    return manager


def test_toggling_auto_persists(manager):
    drive(manager, 'space')
    assert manager.auto
    drive(manager, 'space')
    assert not manager.auto


def test_start_launches_the_next_step(manager, screens):
    drive(manager, 's')
    assert [name for name, _, _ in screens.launched] == [f'p2test_stage_{JD}']


def test_start_queues_while_the_limit_is_full(manager, screens):
    manager.launch('stage', '2459860')  # staging = 1 (and it's listed after JD, as it isn't in nights.txt)
    drive(manager, 's')
    assert [name for name, _, _ in screens.launched] == ['p2test_stage_2459860']
    assert manager.night(JD).state.label == 'queued to stage'
    drive(manager, 's')  # takes it back
    assert manager.night(JD).state.label == 'queued'


def test_run_asks_for_the_job_cap(manager, screens):
    finish(manager.config.state_dir(JD), 'stage', 'build')
    drive(manager, 's', ['5', '0'], 'enter')  # the default (200) is selected, so typing replaces it
    (name, _, env), = screens.launched
    assert name == f'p2test_run_{JD}' and env['MAX_JOBS'] == '50'


def test_approve_writes_the_marker_with_a_note(manager):
    finish(manager.config.state_dir(JD), 'stage', 'build', 'run')
    drive(manager, 'y', list('looks good'), 'enter')
    assert 'looks good' in (manager.config.state_dir(JD) / 'approved').read_text()


def test_approve_can_be_cancelled(manager):
    finish(manager.config.state_dir(JD), 'stage', 'build', 'run')
    drive(manager, 'y', 'escape')
    assert not (manager.config.state_dir(JD) / 'approved').exists()


def test_hold_and_release(manager):
    drive(manager, 'h', 'enter')
    assert (manager.config.state_dir(JD) / 'hold').exists()
    drive(manager, 'h')
    assert not (manager.config.state_dir(JD) / 'hold').exists()


def test_reset_removes_markers(manager):
    state_dir = manager.config.state_dir(JD)
    finish(state_dir, 'stage', 'build', 'run')
    (state_dir / 'approved').write_text('yes\n')

    async def go():
        app = ManagerApp(manager)
        async with app.run_test(size=(160, 40)) as pilot:
            await settle(app, pilot)
            await pilot.press('R')
            await settle(app, pilot)
            await pilot.click('#choice_build')
            await settle(app, pilot)
    asyncio.run(go())
    assert sorted(p.name for p in state_dir.iterdir()) == ['stage.exit', 'stage.started']


def test_adding_nights(manager):
    drive(manager, 'n', list('2459862 2459863'), 'enter')
    assert m.read_queue(manager.config.nights_file) == [JD, '2459862', '2459863']


def test_auto_mode_launches_from_the_tui(manager, screens):
    manager.auto = True
    drive(manager)
    assert [name for name, _, _ in screens.launched] == [f'p2test_stage_{JD}']


def test_the_selection_survives_a_refresh(manager):
    m.add_to_queue(manager.config.nights_file, ['2459862', '2459863'])

    async def go():
        app = ManagerApp(manager)
        async with app.run_test(size=(160, 40)) as pilot:
            await settle(app, pilot)
            await pilot.press('down', 'down')
            await settle(app, pilot)
            app.poll()
            await settle(app, pilot)
            return app.selected_jd()
    assert asyncio.run(go()) == '2459863'


def test_abort_needs_its_button_not_just_enter(manager, screens):
    manager.launch('stage', JD)
    drive(manager, 'x', 'enter')  # the dialog starts on cancel
    assert screens.interrupted == []

    async def go():
        app = ManagerApp(manager)
        async with app.run_test(size=(160, 40)) as pilot:
            await settle(app, pilot)
            await pilot.press('x')
            await settle(app, pilot)
            await pilot.click('#choice_abort')
            await settle(app, pilot)
    asyncio.run(go())
    assert screens.interrupted == [f'p2test_stage_{JD}']


def test_dialogs_fit(manager):
    """A long question wraps, and every button shows (even with many steps), instead of running off the dialog."""
    finish(manager.config.state_dir(JD), 'stage', 'build', 'run')

    async def go():
        app = ManagerApp(manager)
        async with app.run_test(size=(110, 30)) as pilot:
            await settle(app, pilot)
            for key in ('y', 'R'):  # approve's question is long; reset has a button for every step
                await pilot.press(key)
                await settle(app, pilot)
                inside = app.screen.query_one('#dialog').content_region
                for widget in app.screen.query('Label, Button'):
                    assert widget.size.width <= inside.width and inside.contains_region(widget.region), (key, widget)
                await pilot.press('escape')
                await settle(app, pilot)
    asyncio.run(go())
