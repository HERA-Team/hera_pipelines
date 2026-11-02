"""Keeps track of a pipeline's nightly runs, and starts each night's next step when it can.

A pipeline's config.toml (kept beside the pipeline: see README.md) lists the steps each night goes through, such as
stage, build, run, review, prune, and archive. Each step is a bash script that runs in its own detached screen, by
way of scripts/step.sh, which records how it went in marker files under {state_root}/{JD}/. This module only ever
reads those markers (and the makeflow's log), decides what to launch next, and launches it; it never touches data.
All its state is on disk, so it can be stopped and restarted at any time without affecting a running night.

    python manager.py --config CONFIG status             the nights, and where each one is
    python manager.py --config CONFIG tick [--dry-run]   launch whatever can be launched now (once)
    python manager.py --config CONFIG tui                the full-screen interface (see tui.py)

Run with --help for the rest (launch, approve, hold, reset, abort, ...). $OPS_CONFIG can stand in for --config.
"""
import argparse
import dataclasses
import datetime
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
from pathlib import Path

import toml

OPS_DIR = Path(__file__).resolve().parent
SHARED_SCRIPTS = OPS_DIR / 'scripts'
REVIEW = 'review'  # not a step, but the place in [workflow] steps where each night waits for approval
ROOTS = ('nights_root', 'makeflow_root', 'raw_root', 'cold_root', 'state_root')
PLACEHOLDER = 'FILL_ME_IN'
LAUNCH_GRACE = datetime.timedelta(seconds=60)  # how long a launched step may take to write its .started marker

# what a night is called while each of these steps runs, and once it has finished (other steps get "<step> running"
# and "<step> done")
DOING = {'stage': 'staging', 'build': 'building', 'run': 'running', 'prune': 'pruning', 'archive': 'archiving'}
DONE = {'stage': 'staged', 'build': 'built', 'run': 'ran', 'prune': 'pruned', 'archive': 'archived'}


def now():
    return datetime.datetime.now().replace(microsecond=0)


def short_host(host=None):
    return (host or socket.gethostname()).split('.')[0]


##############################################################################################################
# configuration
##############################################################################################################

@dataclasses.dataclass
class Step:
    """One of a night's steps, as the config's [workflow] and [steps.<name>] describe it."""
    name: str
    script: Path               # run as `bash <script> <JD> [<toml>]`
    toml: Path | None = None   # the pipeline toml the script is given, if any
    makeflow: bool = False     # whether it runs that toml's makeflow (so it has progress, and a job cap)
    limit: str | None = None   # the [limits] entry capping how many nights may be in this step at once
    after_review: bool = False


@dataclasses.dataclass
class Config:
    path: Path
    name: str
    steps: list
    nights_root: str
    makeflow_root: str
    raw_root: str
    cold_root: str
    state_root: str
    limits: dict  # [limits] entries named by steps' limit, e.g. {'staging': 1, 'running': 2}
    max_in_flight: int
    min_free_tb: float
    max_jobs: int
    poll_seconds: float
    session_prefix: str
    required_host: str

    @classmethod
    def load(cls, path):
        path = Path(path).resolve()
        cfg = toml.load(path)

        def resolve(value):  # paths in the config are relative to it
            return value if value in ('', PLACEHOLDER) else str((path.parent / value).resolve())

        def problem(message):
            return ValueError(f'{path}: {message}')

        names = cfg.get('workflow', {}).get('steps')
        if not names:
            raise problem('[workflow] steps lists no steps')
        if len(set(names)) != len(names):
            raise problem(f'[workflow] steps names a step (or {REVIEW}) more than once')
        if REVIEW in (names[0], names[-1]):
            raise problem(f'[workflow] steps has {REVIEW} first or last, but it belongs between two steps')
        limits_section = dict(cfg['limits'])
        max_in_flight, min_free_tb = limits_section.pop('max_in_flight'), limits_section.pop('min_free_tb')
        limits_section.pop('cold_min_free_tb', None)  # archive.sh's to check
        default_toml = cfg['workflow'].get('toml')
        steps, after_review = [], False
        for name in names:
            if name == REVIEW:
                after_review = True
                continue
            if not re.fullmatch(r'[a-z][a-z0-9_]*', name):
                raise problem(f'step names are lowercase letters, digits, and underscores, not {name!r}')
            settings = cfg.get('steps', {}).get(name, {})
            unknown = set(settings) - {'script', 'toml', 'makeflow', 'limit'}
            if unknown:
                raise problem(f'[steps.{name}] has unknown settings: {", ".join(sorted(unknown))}')
            # a step's script is beside this config, or else one of the shared ones in operations/scripts/
            script = settings.get('script', f'{name}.sh')
            script = next((place / script for place in (path.parent, SHARED_SCRIPTS) if (place / script).is_file()), None)
            if script is None:
                raise problem(f'no script for step {name}: no {settings.get("script", f"{name}.sh")} beside the config '
                              f'or in {SHARED_SCRIPTS}')
            step_toml = settings.get('toml', default_toml)
            step = Step(name=name, script=script.resolve(), toml=Path(resolve(step_toml)) if step_toml else None,
                        makeflow=settings.get('makeflow', False), limit=settings.get('limit'), after_review=after_review)
            if step.makeflow and step.toml is None:
                raise problem(f'step {name} runs a makeflow, so it needs a toml')
            if step.limit is not None and not isinstance(limits_section.get(step.limit), int):
                raise problem(f'step {name} has limit = "{step.limit}", but [limits] {step.limit} is not set')
            steps.append(step)
        if not steps:
            raise problem('[workflow] steps lists no steps')

        manager = cfg['manager']
        return cls(path=path, name=manager.get('name', path.parent.name), steps=steps,
                   **{key: resolve(cfg['paths'][key]) for key in ROOTS},
                   limits=limits_section, max_in_flight=max_in_flight, min_free_tb=min_free_tb,
                   max_jobs=cfg['makeflow']['max_jobs'], poll_seconds=manager['poll_seconds'],
                   session_prefix=manager['session_prefix'], required_host=manager['required_host'])

    @property
    def step_names(self):
        return [step.name for step in self.steps]

    def step(self, name):
        for step in self.steps:
            if step.name == name:
                return step
        raise ValueError(f'unknown step {name!r} (the steps are {", ".join(self.step_names)})')

    @property
    def nights_file(self):
        return self.path.parent / 'nights.txt'

    def placeholders(self):
        """The [paths] that still need filling in."""
        return [key for key in ROOTS if getattr(self, key) in ('', PLACEHOLDER)]

    def state_dir(self, jd):
        return Path(self.state_root) / str(jd)

    def makeflow_dir(self, jd):
        return Path(self.makeflow_root) / str(jd)

    def makeflow_log(self, jd, step):
        """The log of a makeflow step, named (as build_makeflow_from_config.py names the makeflow) after its toml."""
        return self.makeflow_dir(jd) / (step.toml.stem + '.mf.makeflowlog')

    def session_name(self, step, jd):
        return f'{self.session_prefix}_{step}_{jd}'

    def nb_output_repos(self):
        """Where the makeflows' notebooks are copied for review (their tomls' [NOTEBOOK_OPTS] nb_output_repo)."""
        repos = []
        for step in self.steps:
            try:
                repo = Path(toml.load(step.toml)['NOTEBOOK_OPTS']['nb_output_repo']) if step.makeflow else None
            except (OSError, KeyError, toml.TomlDecodeError):
                repo = None
            if repo and repo not in repos:
                repos.append(repo)
        return repos


def read_queue(nights_file):
    """The JDs in nights.txt, in order (one per line; # starts a comment)."""
    jds = []
    try:
        lines = Path(nights_file).read_text().splitlines()
    except FileNotFoundError:
        return jds
    for line in lines:
        match = re.match(r'\s*(\d{7})\b', line.split('#')[0])
        if match and match.group(1) not in jds:
            jds.append(match.group(1))
    return jds


def add_to_queue(nights_file, jds):
    """Append the given JDs to nights.txt, skipping any already there. Returns the ones added."""
    queued = set(read_queue(nights_file))
    new = [jd for jd in dict.fromkeys(str(jd) for jd in jds) if jd not in queued]
    bad = [jd for jd in new if not re.fullmatch(r'\d{7}', jd)]
    if bad:
        raise ValueError(f'not 7-digit JDs: {" ".join(bad)}')
    if new:
        text = Path(nights_file).read_text() if Path(nights_file).exists() else ''
        with open(nights_file, 'a') as f:
            if text and not text.endswith('\n'):
                f.write('\n')
            f.write(''.join(f'{jd}\n' for jd in new))
    return new


##############################################################################################################
# markers -> state
##############################################################################################################

@dataclasses.dataclass
class StepRecord:
    """What the marker files say about one step of one night."""
    launched: datetime.datetime | None = None  # written by the manager as it launches the screen
    started: datetime.datetime | None = None   # written by step.sh
    host: str | None = None
    exit_code: int | None = None               # written by step.sh when the step ends
    ended: datetime.datetime | None = None
    requested: datetime.datetime | None = None  # started by hand while its limit was full, so to start once there's room
    requested_max_jobs: int | None = None       # (with this job cap, for a makeflow)


@dataclasses.dataclass
class Markers:
    """Everything in one night's state folder."""
    steps: dict
    approved: str | None = None  # the text of the approved marker (who, when, and any note)
    hold: str | None = None


def _parse_time(text):
    try:
        return datetime.datetime.fromisoformat(text)
    except (TypeError, ValueError):
        return None


def read_markers(state_dir, step_names):
    state_dir = Path(state_dir)

    def read(name):
        try:
            return (state_dir / name).read_text().strip()
        except FileNotFoundError:
            return None

    steps = {}
    for step in step_names:
        record = StepRecord()
        if (launched := read(f'{step}.launched')) is not None:
            record.launched = _parse_time(launched.split()[0]) if launched else None
        if (started := read(f'{step}.started')) is not None:
            fields = started.split()
            record.started = _parse_time(fields[0]) if fields else None
            record.host = fields[1] if len(fields) > 1 else None
        if (ended := read(f'{step}.exit')) is not None:
            fields = ended.split()
            record.exit_code = int(fields[0]) if fields and fields[0].lstrip('-').isdigit() else -1
            record.ended = _parse_time(fields[1]) if len(fields) > 1 else None
        if (requested := read(f'{step}.requested')) is not None:
            fields = requested.split()
            record.requested = (_parse_time(fields[0]) if fields else None) or datetime.datetime.min
            record.requested_max_jobs = int(fields[1]) if len(fields) > 1 and fields[1].isdigit() else None
        steps[step] = record
    return Markers(steps=steps, approved=read('approved'), hold=read('hold'))


@dataclasses.dataclass
class NightState:
    """Where a night is: the step it is on, and that step's status.

    status is one of
      waiting    ready for the step to start (for the first step after review, that means approved)
      active     the step is running (or was just launched)
      elsewhere  the step started on another host, so its screen can't be seen from here
      failed     the step exited nonzero
      lost       the step started (or was launched) but neither finished nor has a screen any more
      review     the steps before review are done; waiting for you to approve the night (step is the last of them)
      done       every step has succeeded
    A waiting, failed, or lost step can also be requested: started by hand while its limit was full, so the
    scheduler starts it once there's room (labelled "queued to <step>").
    """
    jd: str
    step: str
    status: str
    held: bool = False
    label: str = ''         # what the TUI calls it, e.g. "staged" or "run failed"
    in_flight: bool = True  # whether it holds space: anywhere from starting its first step to done
    requested: bool = False


def derive_state(jd, markers, live_sessions, config, host=None, at=None):
    """Work out where a night is from its markers and which screens are alive. Pure, apart from the clock."""
    host, at = short_host(host), at or now()
    held = markers.hold is not None

    def state(index, status):
        step = config.steps[index].name
        requested = status in ('waiting', 'failed', 'lost') and markers.steps[step].requested is not None
        if requested:
            label = f'queued to {step}' + (' again' if status != 'waiting' else '')
        elif status == 'waiting':
            if index == 0:
                label = 'queued'
            elif config.steps[index].after_review and not config.steps[index - 1].after_review:
                label = 'approved'
            else:
                previous = config.steps[index - 1].name
                label = DONE.get(previous, f'{previous} done')
        elif status in ('active', 'elsewhere'):
            label = DOING.get(step, f'{step} running') + ('?' if status == 'elsewhere' else '')
        elif status in ('failed', 'lost'):
            label = f'{step} {status}'
        else:
            label = status
        return NightState(jd, step, status, held, label=f'{label} (held)' if held else label,
                          in_flight=not (status == 'done' or (index == 0 and status == 'waiting')), requested=requested)

    for index, step in enumerate(config.steps):
        record = markers.steps[step.name]
        alive = config.session_name(step.name, jd) in live_sessions
        if record.launched and (record.started is None or record.started < record.launched):
            # launched, but step.sh hasn't (yet) recorded that it started
            return state(index, 'active' if alive or at - record.launched < LAUNCH_GRACE else 'lost')
        if record.started is None:
            if step.after_review and markers.approved is None:
                return state(index - 1, 'review')
            return state(index, 'waiting')
        if record.exit_code is None:
            if alive:
                return state(index, 'active')
            if record.host and short_host(record.host) != host:
                return state(index, 'elsewhere')
            return state(index, 'lost')
        if record.exit_code != 0:
            return state(index, 'failed')
    return state(len(config.steps) - 1, 'done')


##############################################################################################################
# scheduling
##############################################################################################################

def in_limits(states, config):
    """The nights each limit's steps hold now, by limit (a step counts while it runs, here or elsewhere)."""
    nights = {limit: [] for limit in config.limits}
    for s in states:
        limit = config.step(s.step).limit
        if limit and s.status in ('active', 'elsewhere'):
            nights[limit].append(s.jd)
    return nights


def plan_actions(states, config, auto, live_sessions=(), free_tb=None):
    """The (step, jd) launches to make now, in order. Pure.

    First the steps queued by hand (started while their limit was full), whether auto is on or not, each as soon as
    its limit has room. Then, with auto on, every night's steps as soon as it is ready for them, except that a step
    with a limit waits until fewer than that many nights are in it (or in any other step sharing its limit), and a
    new night's first step starts only while fewer than max_in_flight nights are under way and (if min_free_tb is
    set) the disk has room. Nothing failed or lost is retried unless it was queued by hand, and nothing held is
    touched.
    """
    busy = {limit: len(jds) for limit, jds in in_limits(states, config).items()}
    in_flight = sum(s.in_flight for s in states)
    disk_ok = config.min_free_tb <= 0 or free_tb is None or free_tb >= config.min_free_tb

    actions = []
    for s in sorted(states, key=lambda s: not s.requested):  # the queued ones first, each lot in queue order
        if s.held or not (s.requested or (auto and s.status == 'waiting')) \
                or config.session_name(s.step, s.jd) in live_sessions:
            continue
        step = config.step(s.step)
        if step.limit and busy[step.limit] >= config.limits[step.limit]:
            continue
        if step is config.steps[0] and s.status == 'waiting':  # a new night
            if not s.requested and (in_flight >= config.max_in_flight or not disk_ok):
                continue  # (one started by hand needn't wait for these, as it wouldn't have with room to start)
            in_flight += 1
        if step.limit:
            busy[step.limit] += 1
        actions.append((s.step, s.jd))
    return actions


##############################################################################################################
# makeflow progress
##############################################################################################################

@dataclasses.dataclass
class MakeflowProgress:
    waiting: int = 0
    running: int = 0
    complete: int = 0
    failed: int = 0
    aborted: int = 0
    total: int = 0
    outcome: str | None = None  # STARTED, COMPLETED, FAILED, or ABORTED: the last such line of the log

    def __str__(self):
        text = f'{self.complete}/{self.total}'
        if self.running:
            text += f', {self.running} running'
        if self.failed:
            text += f', {self.failed} failed'
        if self.aborted:
            text += f', {self.aborted} aborted'
        return text


def parse_makeflowlog(path, tail_bytes=8192):
    """Read the job counts off the end of a makeflow log (None if there is no log yet).

    Each event line is "<time> <node> <new state> <job> <waiting> <running> <complete> <failed> <aborted>
    <nodes in total>"; makeflow also writes "# STARTED", "# COMPLETED", "# FAILED", and "# ABORTED" lines.
    """
    try:
        with open(path, 'rb') as f:
            f.seek(0, os.SEEK_END)
            f.seek(max(0, f.tell() - tail_bytes))
            lines = f.read().decode(errors='replace').splitlines()
    except FileNotFoundError:
        return None
    progress = MakeflowProgress()
    counts_found = False
    for line in reversed(lines):
        fields = line.split()
        if not fields:
            continue
        if fields[0] == '#':
            if progress.outcome is None and len(fields) > 1 and fields[1] in ('STARTED', 'COMPLETED', 'FAILED', 'ABORTED'):
                progress.outcome = fields[1]
        elif not counts_found and len(fields) >= 10 and all(field.lstrip('-').isdigit() for field in fields[:10]):
            (progress.waiting, progress.running, progress.complete,
             progress.failed, progress.aborted, progress.total) = map(int, fields[4:10])
            counts_found = True
        if counts_found and progress.outcome:
            break
    return progress


##############################################################################################################
# screens
##############################################################################################################

DETACH_KEYS = 'Ctrl-T d'  # how to come back from a night's screen attached to from the TUI (see Screens.attach_command)


class Screens:
    """Starts, lists, and talks to the detached screen sessions the steps run in."""

    def live_sessions(self):
        # lines look like "<tab>12345.p2_run_2459862<tab>(10/28/26 14:00:00)<tab>(Detached)", without the date in
        # older versions of screen; a session whose screen process died says (Dead ???) instead
        result = subprocess.run(['screen', '-ls'], capture_output=True, text=True)
        names = set()
        for line in result.stdout.splitlines():
            match = re.match(r'\s*\d+\.(\S+)\s', line)
            if match and '(Dead' not in line:
                names.add(match.group(1))
        return names

    def launch(self, name, command, env):
        subprocess.run(['screen', '-dmS', name] + command, env=env, check=True)

    def attach_command(self, name):
        # with a command key of its own, Ctrl-T, so that DETACH_KEYS come back from it even inside another screen (the
        # manager's, which keeps Ctrl-A)
        return ['screen', '-e', '^Tt', '-x', name]

    def interrupt(self, name):
        """Ctrl-C, as if typed in the screen."""
        subprocess.run(['screen', '-S', name, '-X', 'stuff', '\003'], check=True)


##############################################################################################################
# the manager
##############################################################################################################

@dataclasses.dataclass
class Night:
    jd: str
    markers: Markers
    state: NightState
    progress: MakeflowProgress | None = None  # of the makeflow it is running, or last ran
    since: datetime.datetime | None = None    # when it got to where it is now


class Manager:
    def __init__(self, config, screens=None):
        self.config = config
        self.screens = screens or Screens()
        self.host = short_host()
        self.read_only = False  # set by take_lock, if another manager is running
        self.messages = []      # what the manager has done, for the TUI's log (also printed by the CLI)

    def log(self, message):
        self.messages.append(f'{now():%m-%d %H:%M:%S} {message}')
        self.messages = self.messages[-500:]

    # ----- what's where -----

    def jds(self):
        """The queue's nights in order, then any others that have state, so a night never vanishes mid-run."""
        jds = read_queue(self.config.nights_file)
        state_root = Path(self.config.state_root)
        if state_root.is_dir():
            jds += sorted(p.name for p in state_root.iterdir() if re.fullmatch(r'\d{7}', p.name) and p.name not in jds)
        return jds

    def night(self, jd, live_sessions=None):
        jd = str(jd)
        live = self.screens.live_sessions() if live_sessions is None else live_sessions
        markers = read_markers(self.config.state_dir(jd), self.config.step_names)
        state = derive_state(jd, markers, live, self.config, self.host)
        makeflow = self.makeflow_step(markers, state)
        progress = parse_makeflowlog(self.config.makeflow_log(jd, makeflow)) if makeflow else None
        return Night(jd, markers, state, progress, self._since(markers, state))

    def nights(self, live_sessions=None):
        live = self.screens.live_sessions() if live_sessions is None else live_sessions
        return [self.night(jd, live) for jd in self.jds()]

    def makeflow_step(self, markers, state):
        """The makeflow step the night is in, or last ran (None if it hasn't begun one)."""
        steps = self.config.steps[:self.config.step_names.index(state.step) + 1]
        return next((step for step in reversed(steps) if step.makeflow
                     and (markers.steps[step.name].started or markers.steps[step.name].launched)), None)

    def _since(self, markers, state):
        record = markers.steps[state.step]
        if state.status in ('active', 'elsewhere', 'lost'):
            return record.started if record.started and not (record.launched and record.launched > record.started) \
                else record.launched
        if state.status in ('failed', 'review', 'done'):
            return record.ended
        index = self.config.step_names.index(state.step)  # waiting: since the step before ended
        return markers.steps[self.config.step_names[index - 1]].ended if index else None

    def free_tb(self):
        try:
            return shutil.disk_usage(self.config.nights_root).free / 1e12
        except (OSError, TypeError):
            return None

    def launch_problem(self):
        """Why nothing can be launched from here right now (None if it can)."""
        if missing := self.config.placeholders():
            return f'fill in [paths] {", ".join(missing)} in {self.config.path}'
        if self.config.required_host and self.host != short_host(self.config.required_host):
            return f'this is {self.host}, but steps must run on {self.config.required_host}'
        return None

    # ----- auto mode and the lock -----

    @property
    def auto_file(self):
        return Path(self.config.state_root) / 'auto_mode'

    @property
    def auto(self):
        try:
            return self.auto_file.read_text().strip() == 'on'
        except (FileNotFoundError, TypeError):
            return False

    @auto.setter
    def auto(self, on):
        if missing := self.config.placeholders():
            raise RuntimeError(f'fill in [paths] {", ".join(missing)} in {self.config.path} first')
        self.auto_file.parent.mkdir(parents=True, exist_ok=True)
        self.auto_file.write_text('on\n' if on else 'off\n')
        self.log(f'auto mode {"on" if on else "off"}')

    @property
    def lock_file(self):
        return Path(self.config.state_root) / 'manager.lock'

    def lock_holder(self):
        """'host pid' of another live manager holding the lock, or None."""
        try:
            host, pid = self.lock_file.read_text().split()[:2]
        except (FileNotFoundError, ValueError):
            return None
        if host == self.host:
            if int(pid) == os.getpid():
                return None
            try:
                os.kill(int(pid), 0)
            except ProcessLookupError:
                return None  # stale
            except PermissionError:
                pass
        return f'{host} {pid}'

    def take_lock(self):
        """Become the one manager that launches things; if another is running, stay read-only."""
        if self.config.placeholders():  # nowhere to put the lock, and nothing can launch anyway
            self.read_only = True
            return
        if holder := self.lock_holder():
            self.read_only = True
            self.log(f'another manager is running ({holder}), so this one only watches')
            return
        self.lock_file.parent.mkdir(parents=True, exist_ok=True)
        self.lock_file.write_text(f'{self.host} {os.getpid()}\n')

    def release_lock(self):
        try:
            if self.lock_file.read_text().split()[:2] == [self.host, str(os.getpid())]:
                self.lock_file.unlink()
        except (FileNotFoundError, ValueError):
            pass

    # ----- actions -----

    def launch(self, step, jd, max_jobs=None, live_sessions=None):
        """Start one step for one night by hand, in its own screen, or, while the step's limit is full, queue it: the
        scheduler then starts it as soon as there's room, before anything else and whether auto is on or not.
        Returns the nights filling the limit if it was queued (and [] if it started)."""
        step = self.config.step(step)
        live = self.screens.live_sessions() if live_sessions is None else live_sessions
        self._check(step, jd, live)
        if step.limit:
            states = [derive_state(other, read_markers(self.config.state_dir(other), self.config.step_names), live,
                                   self.config, self.host) for other in self.jds() if other != str(jd)]
            full = in_limits(states, self.config)[step.limit]
            if len(full) >= self.config.limits[step.limit]:
                state_dir = self.config.state_dir(jd)
                state_dir.mkdir(parents=True, exist_ok=True)
                (state_dir / f'{step.name}.requested').write_text(f'{now().isoformat()} {max_jobs or ""}'.rstrip() + '\n')
                self.log(f'queued {step.name} {jd}' + (f' (max_jobs {max_jobs})' if max_jobs else '') +
                         f": [limits] {step.limit} = {self.config.limits[step.limit]}, and it's full ({', '.join(full)})")
                return full
        self._start(step, jd, max_jobs, live)
        return []

    def unqueue(self, jd):
        """Take back the night's queued step (see launch)."""
        for request in self.config.state_dir(jd).glob('*.requested'):
            request.unlink()
            self.log(f'unqueued {request.stem} {jd}')

    def _check(self, step, jd, live):
        """Raise if the step can't start for the night now, whatever its limit."""
        if problem := self.launch_problem():
            raise RuntimeError(problem)
        name = self.config.session_name(step.name, jd)
        if name in live:
            raise RuntimeError(f'screen {name} is still open: attach to it and exit it first')
        if step.after_review and not (self.config.state_dir(jd) / 'approved').exists():
            raise RuntimeError(f'{jd} has not been approved')

    def _start(self, step, jd, max_jobs, live):
        """Start one step for one night in its own screen, now (see launch, and tick, whose plan keeps to the limits)."""
        self._check(step, jd, live)
        name = self.config.session_name(step.name, jd)
        state_dir = self.config.state_dir(jd)
        (state_dir / 'logs').mkdir(parents=True, exist_ok=True)
        (state_dir / f'{step.name}.exit').unlink(missing_ok=True)
        (state_dir / f'{step.name}.requested').unlink(missing_ok=True)
        (state_dir / f'{step.name}.launched').write_text(f'{now().isoformat()} {self.host}\n')
        env = dict(os.environ, OPS_CONFIG=str(self.config.path), OPS_SHELL_ON_FAILURE='1')
        if max_jobs:
            env['MAX_JOBS'] = str(max_jobs)
        self.screens.launch(name, ['bash', str(SHARED_SCRIPTS / 'step.sh'), step.name, str(jd)], env)
        self.log(f'launched {step.name} {jd}' + (f' (max_jobs {max_jobs})' if max_jobs else '') + f' in screen {name}')

    def step_settings(self, step, jd):
        """For step.sh: what to run for this step of this night, and why it can't run yet (if it can't)."""
        step = self.config.step(step)
        markers = read_markers(self.config.state_dir(jd), self.config.step_names)
        refusal = ''
        for earlier in self.config.steps[:self.config.steps.index(step)]:
            if markers.steps[earlier.name].exit_code != 0:
                refusal = f'{earlier.name} has not succeeded for {jd}, so {step.name} cannot run yet'
                break
        if not refusal and step.after_review and markers.approved is None:
            refusal = f'{jd} has not been approved (no {self.config.state_dir(jd) / "approved"})'
        return {'script': step.script, 'toml': step.toml or '', 'makeflow': int(step.makeflow),
                'pipeline': self.config.name, 'refusal': refusal}

    def tick(self, dry_run=False):
        """One pass of the scheduler: launch everything that can be launched now. Returns what it (would have) launched."""
        if self.read_only or self.launch_problem():
            return []
        live = self.screens.live_sessions()
        nights = {night.jd: night for night in self.nights(live)}
        actions = plan_actions([night.state for night in nights.values()], self.config, self.auto, live, self.free_tb())
        if not dry_run:
            for step, jd in actions:
                max_jobs = nights[jd].markers.steps[step].requested_max_jobs  # as it was queued with, if it was
                try:
                    self._start(self.config.step(step), jd, max_jobs, live)  # the plan already keeps to the limits
                except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
                    self.log(f'could not launch {step} {jd}: {error}')
        return actions

    def next_step(self, night):
        """The step to launch for the night by hand: the waiting one, or the failed or lost one again."""
        if night.state.status in ('waiting', 'failed', 'lost'):
            return night.state.step
        return None

    def approve(self, jd, note=''):
        night = self.night(jd)
        if night.state.status != 'review':
            raise RuntimeError(f'{jd} is {night.state.label}, not waiting for review')
        user = os.environ.get('USER', '?')
        (self.config.state_dir(jd) / 'approved').write_text(f'{now().isoformat()} {user} {note}'.rstrip() + '\n')
        self.log(f'approved {jd}' + (f': {note}' if note else ''))

    def hold(self, jd, note=''):
        self.config.state_dir(jd).mkdir(parents=True, exist_ok=True)
        (self.config.state_dir(jd) / 'hold').write_text(f'{now().isoformat()} {note}'.rstrip() + '\n')
        self.log(f'held {jd}' + (f': {note}' if note else ''))

    def unhold(self, jd):
        (self.config.state_dir(jd) / 'hold').unlink(missing_ok=True)
        self.log(f'released {jd}')

    def reset(self, jd, from_step):
        """Forget the given step and every later one (their markers, not their logs or any data), so they run again.

        Resetting a step before review also withdraws the night's approval.
        """
        steps = self.config.steps[self.config.steps.index(self.config.step(from_step)):]
        live = self.screens.live_sessions()
        for step in steps:
            if self.config.session_name(step.name, jd) in live:
                raise RuntimeError(f'screen {self.config.session_name(step.name, jd)} is still open: close it first')
        state_dir = self.config.state_dir(jd)
        for step in steps:
            for suffix in ('requested', 'launched', 'started', 'exit'):
                (state_dir / f'{step.name}.{suffix}').unlink(missing_ok=True)
        if not steps[0].after_review:
            (state_dir / 'approved').unlink(missing_ok=True)
        self.log(f'reset {jd} from {from_step}')

    def abort(self, jd):
        """Ctrl-C the night's running step (for a makeflow, that aborts its jobs)."""
        night = self.night(jd)
        if night.state.status != 'active':
            raise RuntimeError(f'{jd} is {night.state.label}: nothing to abort')
        self.screens.interrupt(self.config.session_name(night.state.step, jd))
        self.log(f'sent Ctrl-C to {night.state.step} {jd}')

    # ----- details, for review -----

    def session_for(self, night):
        """The screen to attach to for this night, if one is open."""
        name = self.config.session_name(night.state.step, night.jd)
        return name if name in self.screens.live_sessions() else None

    def log_path(self, jd, step):
        return self.config.state_dir(jd) / 'logs' / f'{step}.log'

    def log_tail(self, jd, step, n_lines=15):
        try:
            with open(self.log_path(jd, step), 'rb') as f:
                f.seek(0, os.SEEK_END)
                f.seek(max(0, f.tell() - 16384))
                return f.read().decode(errors='replace').splitlines()[-n_lines:]
        except FileNotFoundError:
            return []

    def error_logs(self, jd):
        """The makeflows' failed jobs' logs (from their current attempts)."""
        return sorted(self.config.makeflow_dir(jd).glob('*.log.error'))

    def notebooks(self, jd):
        """The night's notebooks in the notebook output repositories."""
        return sorted(notebook for repo in self.config.nb_output_repos() if repo.is_dir()
                      for notebook in repo.glob(f'*/*_{jd}.html'))

    def pipeline_status_command(self, night):
        """hera_opm's pipeline_status.py, for the makeflow the night is in or last ran (None if it hasn't begun one)."""
        step = self.makeflow_step(night.markers, night.state)
        if step is None:
            return None
        return ['pipeline_status.py', '--config_file', str(step.toml), '--working_dir',
                str(self.config.makeflow_dir(night.jd))]


##############################################################################################################
# command line
##############################################################################################################

def format_age(since):
    if since is None:
        return ''
    seconds = int((now() - since).total_seconds())
    if seconds < 3600:
        return f'{seconds // 60}m'
    if seconds < 86400:
        return f'{seconds // 3600}h{seconds % 3600 // 60:02d}m'
    return f'{seconds // 86400}d{seconds % 86400 // 3600:02d}h'


def status_table(manager):
    nights = manager.nights()
    rows = [('JD', 'STATE', 'MAKEFLOW', 'SINCE', 'NOTE')]
    for night in nights:
        note = night.markers.hold or night.markers.approved or ''
        rows.append((night.jd, night.state.label, str(night.progress or ''), format_age(night.since),
                     ' '.join(note.split()[1:])))
    widths = [max(len(row[i]) for row in rows) for i in range(len(rows[0]))]
    lines = ['  '.join(cell.ljust(width) for cell, width in zip(row, widths)).rstrip() for row in rows]
    counts = {}
    for night in nights:
        counts[night.state.label] = counts.get(night.state.label, 0) + 1
    summary = ', '.join(f'{n} {label}' for label, n in counts.items())
    header = f'{manager.config.name}: auto {"on" if manager.auto else "off"}; {summary or "no nights"}'
    if problem := manager.launch_problem():
        header += f'\nNOTHING CAN LAUNCH: {problem}'
    return header + '\n' + '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', default=os.environ.get('OPS_CONFIG'),
                        help="the pipeline's operations config.toml (default: $OPS_CONFIG)")
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('status', help='list the nights and where each one is')
    tick = commands.add_parser('tick', help='launch whatever can be launched now, once (as auto mode does)')
    tick.add_argument('--dry-run', action='store_true', help='only say what would be launched')
    auto = commands.add_parser('auto', help='turn auto mode on or off (for the TUI, and tick)')
    auto.add_argument('setting', choices=['on', 'off'])
    launch = commands.add_parser('launch', help="start one step for one night, in its own screen (or, while its limit "
                                               "is full, queue it, to start once there's room)")
    launch.add_argument('step')
    launch.add_argument('jd')
    launch.add_argument('--max-jobs', type=int, help="for a makeflow: its cap on simultaneous jobs")
    add = commands.add_parser('add', help='add nights to the queue (nights.txt)')
    add.add_argument('jds', nargs='+')
    approve = commands.add_parser('approve', help='approve a reviewed night, so its steps after review run')
    approve.add_argument('jd')
    approve.add_argument('--note', default='')
    hold = commands.add_parser('hold', help="don't let auto mode touch a night")
    hold.add_argument('jd')
    hold.add_argument('--note', default='')
    unhold = commands.add_parser('unhold', help='release a held night')
    unhold.add_argument('jd')
    unqueue = commands.add_parser('unqueue', help="take back a night's queued step (see launch)")
    unqueue.add_argument('jd')
    reset = commands.add_parser('reset', help="forget a step and the ones after it (markers only), so they run again")
    reset.add_argument('jd')
    reset.add_argument('--from', dest='from_step', required=True)
    abort = commands.add_parser('abort', help="Ctrl-C a night's running step")
    abort.add_argument('jd')
    commands.add_parser('tui', help='the full-screen interface')
    settings = commands.add_parser('step-settings', help="(for step.sh) a step's script and toml, as shell variables")
    settings.add_argument('step')
    settings.add_argument('jd')
    args = parser.parse_args(argv)
    if args.config is None:
        parser.error("say which pipeline's config to use, with --config (or $OPS_CONFIG)")

    try:
        manager = Manager(Config.load(args.config))
        if args.command == 'tui':
            import tui
            tui.run(manager)
            return 0
        if args.command == 'status':
            print(status_table(manager))
        elif args.command == 'tick':
            if holder := manager.lock_holder():
                sys.exit(f'another manager is running ({holder}); not launching anything from here')
            if problem := manager.launch_problem():
                sys.exit(f'nothing can launch: {problem}')
            if not manager.auto:
                print('auto mode is off, so tick only launches the steps queued by hand (python manager.py auto on)')
            actions = manager.tick(dry_run=args.dry_run)
            print('\n'.join(f'{"would launch" if args.dry_run else "launched"} {step} {jd}' for step, jd in actions)
                  or 'nothing to launch')
        elif args.command == 'auto':
            manager.auto = args.setting == 'on'
        elif args.command == 'launch':
            manager.launch(args.step, args.jd, max_jobs=args.max_jobs)
        elif args.command == 'add':
            added = add_to_queue(manager.config.nights_file, args.jds)
            print(f'added {" ".join(added)}' if added else 'all already queued')
        elif args.command == 'approve':
            manager.approve(args.jd, args.note)
        elif args.command == 'hold':
            manager.hold(args.jd, args.note)
        elif args.command == 'unhold':
            manager.unhold(args.jd)
        elif args.command == 'unqueue':
            manager.unqueue(args.jd)
        elif args.command == 'reset':
            manager.reset(args.jd, args.from_step)
        elif args.command == 'abort':
            manager.abort(args.jd)
        elif args.command == 'step-settings':
            for key, value in manager.step_settings(args.step, args.jd).items():
                print(f'{key}={shlex.quote(str(value))}')
    except (RuntimeError, ValueError) as error:
        sys.exit(f'error: {error}')
    for message in manager.messages:
        print(message)
    return 0


if __name__ == '__main__':
    sys.exit(main())
