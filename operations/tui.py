"""The full-screen interface to manager.py: a live table of the nights, what the selected one is doing, and keys to
start, attach to, approve, hold, abort, or reset them. Quitting it never affects a running night.

    python tui.py --config <pipeline's operations config.toml>      (or: python manager.py --config ... tui)

Meant to run in a screen of its own on the host the makeflows run on (see README.md).
"""
import argparse
import os
import shlex
import subprocess
import sys
import threading

from rich.text import Text
from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import Button, DataTable, Footer, Input, Label, RichLog, Static

from manager import DETACH_KEYS, Config, Manager, add_to_queue, format_age, in_limits, short_host

STATUS_STYLES = {'waiting': '', 'active': 'cyan', 'elsewhere': 'magenta', 'failed': 'bold red',
                 'lost': 'bold red', 'review': 'bold yellow', 'done': 'green'}


def status_style(state):
    return 'blue' if state.requested else STATUS_STYLES[state.status]  # queued by hand: starts once there's room


class Prompt(ModalScreen):
    """Ask for a line of text (dismisses with it, or None if cancelled)."""
    AUTO_FOCUS = 'Input'

    def __init__(self, question, value='', placeholder=''):
        super().__init__()
        self.question, self.value, self.placeholder = question, value, placeholder

    def compose(self) -> ComposeResult:
        with Vertical(id='dialog'):
            yield Label(self.question)
            yield Input(value=self.value, placeholder=self.placeholder)
            yield Label('[dim]Enter to confirm, Escape to cancel[/]')

    def on_input_submitted(self, event):
        self.dismiss(event.value)

    def key_escape(self):
        self.dismiss(None)


class Choose(ModalScreen):
    """Pick one of a few buttons (dismisses with its label, or None if cancelled), with the arrow keys or Tab."""
    AUTO_FOCUS = '#cancel'  # so a stray Enter does nothing
    COLUMNS = 4             # as #choices' grid-size, in ManagerApp.CSS
    BINDINGS = [Binding('left', 'move(-1)', show=False), Binding('right', 'move(1)', show=False),
                Binding('up', f'move({-COLUMNS})', show=False), Binding('down', f'move({COLUMNS})', show=False)]

    def __init__(self, question, choices):
        super().__init__()
        self.question, self.choices = question, choices

    def compose(self) -> ComposeResult:
        with Vertical(id='dialog'):
            yield Label(self.question)
            with Horizontal(id='choices'):
                for choice in self.choices:
                    yield Button(choice, id=f'choice_{choice}')
                yield Button('cancel', id='cancel')
            yield Label('[dim]arrow keys (or Tab) to move, Enter to choose, Escape to cancel[/]')

    def action_move(self, by):
        """Focus the button by along (a row up or down, if by is a whole row; left and right go round)."""
        buttons = list(self.query(Button))
        index = buttons.index(self.focused) if self.focused in buttons else len(buttons) - 1
        if abs(by) == 1:
            index = (index + by) % len(buttons)
        else:
            index = min(max(index + by, 0), len(buttons) - 1)
        self.set_focus(buttons[index])

    def on_button_pressed(self, event):
        self.dismiss(None if event.button.id == 'cancel' else str(event.button.label))

    def key_escape(self):
        self.dismiss(None)


class ManagerApp(App):
    CSS = """
    #status { height: auto; padding: 0 1; background: $boost; }
    #main { height: 1fr; }
    #nights { width: 3fr; }
    #detail-scroll { width: 2fr; border-left: solid $primary; padding: 0 1; }
    #events { height: 7; border-top: solid $primary; }
    #dialog { width: 72; height: auto; padding: 1 2; border: thick $primary; background: $surface; }
    #dialog Label { width: 100%; }  /* so a long question wraps instead of running off the edge */
    #choices { layout: grid; grid-size: 4; grid-gutter: 1; grid-rows: 3; height: auto; margin-top: 1; }
    #choices Button { width: 100%; min-width: 0; }  /* four to a row, so a pipeline with many steps still fits */
    #choices Button:focus { background: $accent; text-style: bold; }  /* plain to see, as it's chosen by keys */
    Prompt, Choose { align: center middle; }
    """
    BINDINGS = [
        Binding('space', 'toggle_auto', 'auto'),
        Binding('s', 'start', 'start/retry'),
        Binding('a', 'attach', 'attach'),
        Binding('l', 'log', 'log'),
        Binding('e', 'errors', 'errors'),
        Binding('y', 'approve', 'approve'),
        Binding('h', 'hold', 'hold'),
        Binding('n', 'add', 'add'),
        Binding('p', 'pipeline_status', 'status'),
        Binding('x', 'abort', 'abort'),
        Binding('R', 'reset', 'reset'),
        Binding('g', 'refresh', 'refresh', show=False),
        Binding('q', 'quit', 'quit'),
    ]

    def __init__(self, manager):
        super().__init__()
        self.manager = manager
        self.title = f'{manager.config.name} nights'
        self.nights = []
        self.shown = 0  # how many of the manager's messages are already in the events log
        self.busy = threading.Lock()  # so that the scheduler (in its thread) and a keypress never launch at once

    def compose(self) -> ComposeResult:
        yield Static(id='status')
        with Horizontal(id='main'):
            yield DataTable(id='nights', cursor_type='row', zebra_stripes=True)
            with VerticalScroll(id='detail-scroll'):
                yield Static(id='detail')
        events = RichLog(id='events', wrap=True, markup=False)
        events.can_focus = False
        yield events
        yield Footer()

    def on_mount(self):
        table = self.query_one('#nights', DataTable)
        table.add_columns('JD', 'state', 'makeflow', 'since', 'note')
        table.focus()  # so the arrow keys move through the nights
        self.manager.take_lock()
        if self.manager.other_manager:
            self.notify(f'Another manager is running ({self.manager.other_manager}), so this one only watches.',
                        severity='warning', timeout=15)
        if os.environ.get('STY'):
            self.manager.log('this is inside a screen, so the mouse is off')
        self.poll()
        self.set_interval(self.manager.config.poll_seconds, self.poll)

    def on_unmount(self):
        self.manager.release_lock()

    # ----- refreshing -----

    @work(thread=True, exclusive=True, group='poll')
    def poll(self):
        """Run the scheduler (when this manager may), then reread everything. In a thread: Lustre can be slow."""
        try:
            with self.busy:
                if self.manager.read_only:
                    self.manager.take_lock()  # so that this one takes over once the other has gone
                self.manager.tick()
            nights = self.manager.nights()
            free_tb = self.manager.free_tb()
        except Exception as error:  # keep polling through a bad read (Lustre hiccup, half-written file, ...)
            self.manager.log(f'refresh failed: {error!r}')
            nights, free_tb = self.nights, None
        self.call_from_thread(self.show, nights, free_tb)

    def show(self, nights, free_tb):
        self.nights = nights
        table = self.query_one('#nights', DataTable)
        selected = self.selected_jd()
        table.clear()
        for night in nights:
            note = night.markers.hold if night.state.held else night.markers.approved
            note = ' '.join((note or '').split()[1:])
            table.add_row(night.jd, Text(night.state.label, style=status_style(night.state)),
                          str(night.progress or ''), format_age(night.since), note, key=night.jd)
        jds = [night.jd for night in nights]
        if selected in jds:
            table.move_cursor(row=jds.index(selected), scroll=False)

        config = self.manager.config
        states = [night.state for night in nights]
        status = Text()
        status.append('AUTO ON' if self.manager.auto else 'AUTO OFF: no new nights',
                      style='bold black on green' if self.manager.auto else 'bold black on yellow')
        busy = in_limits(states, config)
        for limit, cap in config.limits.items():  # e.g. how many nights are staging, and how many running makeflows
            status.append(f'   {limit} {len(busy[limit])}/{cap}')
        status.append(f'   in flight {sum(s.in_flight for s in states)}/{config.max_in_flight}'
                      f'   to review {sum(s.status == "review" for s in states)}'
                      f'   failed {sum(s.status in ("failed", "lost") for s in states)}'
                      f'   done {sum(s.status == "done" for s in states)}/{len(states)}')
        if free_tb is not None:
            status.append(f'   {free_tb:.1f} TB free')
        status.append(f'   {self.manager.host}', style='dim')
        if problem := self.manager.launch_problem():
            status.append(f'\nNOTHING CAN LAUNCH: {problem}', style='bold red')
        elif self.manager.read_only:
            status.append(f'\nREAD-ONLY: another manager ({self.manager.other_manager}) holds '
                          f'{self.manager.lock_file}, so this one only watches until it quits', style='bold red')
        self.query_one('#status', Static).update(status)

        events = self.query_one('#events', RichLog)
        for message in self.manager.messages[self.shown:]:
            events.write(message)
        self.shown = len(self.manager.messages)
        self.show_detail()

    def selected_jd(self):
        table = self.query_one('#nights', DataTable)
        if not self.nights or table.cursor_row is None or table.cursor_row >= len(self.nights):
            return None
        return self.nights[table.cursor_row].jd

    def selected(self):
        jd = self.selected_jd()
        return next((night for night in self.nights if night.jd == jd), None)

    def on_data_table_row_highlighted(self, event):
        self.show_detail()

    def show_detail(self):
        self.load_detail(self.selected())

    @work(thread=True, exclusive=True, group='detail')
    def load_detail(self, night):
        text = self.describe(night) if night else Text('No nights yet: press n to add some (or edit nights.txt).')
        self.call_from_thread(self.query_one('#detail', Static).update, text)

    def describe(self, night):
        """The detail pane: the night's steps, its makeflow, its screen, the end of its log, and its notebooks."""
        manager, state = self.manager, night.state
        text = Text()
        text.append(f'{night.jd}  ', style='bold')
        text.append(state.label, style=status_style(state))
        if night.progress:
            text.append(f'   makeflow {night.progress}')
        text.append('\n\n')
        for step in manager.config.step_names:
            record = night.markers.steps[step]
            if not (record.started or record.launched):
                continue
            began = record.started or record.launched
            line = f'{step:8s} {began:%m-%d %H:%M}'
            if record.ended and record.exit_code is not None:
                line += f' → {record.ended:%m-%d %H:%M}  ({_duration(began, record.ended)})'
                line += '' if record.exit_code == 0 else f'  exit {record.exit_code}'
            if record.host and short_host(record.host) != manager.host:
                line += f'  on {record.host}'
            text.append(line + '\n', style='red' if record.exit_code not in (None, 0) else '')
        if night.markers.approved:
            text.append(f'approved {night.markers.approved}\n', style='green')
        if night.markers.hold:
            text.append(f'held {night.markers.hold}\n', style='yellow')

        if session := manager.session_for(night):
            text.append(f'\nscreen {session} is open (a to attach)\n', style='cyan')
        if manager.config.step(state.step).makeflow:
            n_errors = len(manager.error_logs(night.jd))
            if n_errors:
                text.append(f'{n_errors} failed jobs (e to read their logs)\n', style='red')
        if state.status == 'review':
            notebooks = manager.notebooks(night.jd)
            text.append(f'\n{len(notebooks)} notebooks for review:\n', style='bold yellow')
            for notebook in notebooks:
                text.append(f'  {notebook}\n')
            after = [step.name for step in manager.config.steps if step.after_review]
            text.append(f'y to approve (then it goes on to {", ".join(after)}), h to hold\n', style='yellow')

        step = state.step
        if lines := manager.log_tail(night.jd, step):
            text.append(f'\n— end of {step}.log (l for all of it) —\n', style='dim')
            text.append('\n'.join(lines) + '\n', style='dim')
        return text

    # ----- actions -----

    def need_night(self):
        night = self.selected()
        if night is None:
            self.notify('No night selected.', severity='warning')
        return night

    def attempt(self, action, *args, **kwargs):
        """Run a manager action, turning its complaints into notifications, then refresh. Returns what it did."""
        result = None
        try:
            with self.busy:
                result = action(*args, **kwargs)
        except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
            self.notify(str(error), severity='error', timeout=10)
        self.poll()
        return result

    def action_refresh(self):
        self.poll()

    def action_toggle_auto(self):
        if self.manager.read_only and not self.manager.auto:
            self.notify(f'This manager only watches: {self.manager.launch_problem() or "another one holds the lock"}.',
                        severity='warning')
            return
        self.attempt(setattr, self.manager, 'auto', not self.manager.auto)

    def action_start(self):
        if not (night := self.need_night()):
            return
        step = self.manager.next_step(night)
        if night.state.requested:  # s again takes it back
            self.attempt(self.manager.unqueue, night.jd)
            self.notify(f'{night.jd} is no longer queued to {step}.')
        elif step is None:
            self.notify(f'{night.jd} is {night.state.label}: nothing to start.', severity='warning')
        elif self.manager.config.step(step).makeflow:
            def run(value):
                if value is None:
                    return
                if not value.strip().isdigit() or int(value) < 1:
                    self.notify(f'{value!r} is not a number of jobs.', severity='error')
                    return
                self.start_step(step, night.jd, max_jobs=int(value))
            which = 'makeflow' if step == 'run' else f'{step} makeflow'
            self.push_screen(Prompt(f"Run (or resume) {night.jd}'s {which}. At most how many jobs at once?",
                                    str(self.manager.config.max_jobs)), run)
        else:
            self.start_step(step, night.jd)

    def start_step(self, step, jd, max_jobs=None):
        if full := self.attempt(self.manager.launch, step, jd, max_jobs=max_jobs):
            limit = self.manager.config.step(step).limit
            self.notify(f"[limits] {limit} is full ({', '.join(full)}), so {jd} is queued to {step}: it starts as soon "
                        f"as there's room (s again takes it back).")

    def run_suspended(self, command, hint=''):
        """Hand the terminal over to a command (screen, less), and come back when it exits."""
        with self.suspend():
            if hint:
                print(hint)
            subprocess.run(command)
        self.poll()

    def action_attach(self):
        if not (night := self.need_night()):
            return
        if not (session := self.manager.session_for(night)):
            self.notify(f'{night.jd} has no open screen.', severity='warning')
            return
        self.run_suspended(self.manager.screens.attach_command(session),
                           f'Attaching to {session}; detach with {DETACH_KEYS} to come back.')

    def action_log(self):
        if not (night := self.need_night()):
            return
        path = self.manager.log_path(night.jd, night.state.step)
        if not path.exists():
            self.notify(f'No {night.state.step} log for {night.jd} yet.', severity='warning')
            return
        self.run_suspended(['less', '+G', str(path)])

    def action_errors(self):
        if not (night := self.need_night()):
            return
        logs = self.manager.error_logs(night.jd)
        if not logs:
            self.notify(f'No failed jobs in {self.manager.config.makeflow_dir(night.jd)}.')
            return
        self.run_suspended(['less'] + [str(log) for log in logs],
                           f'{len(logs)} failed jobs: :n and :p in less step through them.')

    def action_pipeline_status(self):
        if not (night := self.need_night()):
            return
        if not (command := self.manager.pipeline_status_command(night)):
            self.notify(f'{night.jd} has not begun a makeflow yet.', severity='warning')
            return
        self.run_suspended(['bash', '-c', f'{shlex.join(command)} 2>&1 | less'])

    def action_approve(self):
        if not (night := self.need_night()):
            return
        if night.state.status != 'review':
            self.notify(f'{night.jd} is {night.state.label}, not waiting for review.', severity='warning')
            return
        after = ' and '.join(step.name for step in self.manager.config.steps if step.after_review)
        self.push_screen(Prompt(f'Approve {night.jd}? It then goes on to {after}. Note (optional):'),
                         lambda note: note is not None and self.attempt(self.manager.approve, night.jd, note))

    def action_hold(self):
        if not (night := self.need_night()):
            return
        if night.state.held:
            self.attempt(self.manager.unhold, night.jd)
        else:
            self.push_screen(Prompt(f'Hold {night.jd}, so nothing starts for it unless you start it? Note (optional):'),
                             lambda note: note is not None and self.attempt(self.manager.hold, night.jd, note))

    def action_add(self):
        def add(text):
            if text:
                self.attempt(lambda: self.manager.log(
                    f'queued {" ".join(add_to_queue(self.manager.config.nights_file, text.split())) or "nothing new"}'))
        self.push_screen(Prompt('Add nights to the queue (JDs, separated by spaces):', placeholder='2459861 2459862'), add)

    def action_abort(self):
        if not (night := self.need_night()):
            return
        if night.state.status != 'active':
            self.notify(f'{night.jd} is {night.state.label}: nothing to abort.', severity='warning')
            return
        self.push_screen(Choose(f'Send Ctrl-C to {night.jd}\'s {night.state.step}? (For a makeflow, that aborts its jobs.)',
                                ['abort']),
                         lambda choice: choice and self.attempt(self.manager.abort, night.jd))

    def action_reset(self):
        if not (night := self.need_night()):
            return
        self.push_screen(Choose(f'Forget which step of {night.jd}, and every one after it, so they run again? '
                                'Only markers are removed, never data; resetting a step before review also '
                                'withdraws approval.', self.manager.config.step_names),
                         lambda step: step and self.attempt(self.manager.reset, night.jd, step))


def _duration(start, end):
    seconds = int((end - start).total_seconds())
    return f'{seconds // 3600}h{seconds % 3600 // 60:02d}m' if seconds >= 3600 else f'{seconds // 60}m{seconds % 60:02d}s'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', default=os.environ.get('OPS_CONFIG'),
                        help="the pipeline's operations config.toml (default: $OPS_CONFIG)")
    args = parser.parse_args(argv)
    if args.config is None:
        parser.error("say which pipeline's config to use, with --config (or $OPS_CONFIG)")
    run(Manager(Config.load(args.config)))


def run(manager):
    # No mouse inside screen: screen passes clicks on in the old X10 encoding, whose bytes past column 95 aren't
    # UTF-8, and Textual's input reader dies on them.
    ManagerApp(manager).run(mouse=not os.environ.get('STY'))


if __name__ == '__main__':
    sys.exit(main())
