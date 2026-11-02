"""Real screens (where screen is installed): attached from inside the manager's own screen, as the TUI does, a night's
screen detaches with DETACH_KEYS and leaves the manager's attached."""
import os
import pty
import select
import shlex
import shutil
import subprocess
import time

import pytest

import manager as m

pytestmark = pytest.mark.skipif(shutil.which('screen') is None, reason='needs screen')


def pump(fd, until, timeout=10):
    """Read (and drop) the terminal's output, so screen never blocks on it, until until() or the timeout."""
    end = time.time() + timeout
    while time.time() < end and not until():
        if select.select([fd], [], [], 0.1)[0]:
            try:
                os.read(fd, 65536)
            except OSError:
                break
    return until()


def test_detaching_from_a_night_inside_the_managers_screen(tmp_path):
    (tmp_path / 'screens').mkdir(mode=0o700)
    (tmp_path / 'screenrc').write_text('')  # screen's defaults (Ctrl-A), whatever ~/.screenrc says
    env = dict(os.environ, SCREENDIR=str(tmp_path / 'screens'), SCREENRC=str(tmp_path / 'screenrc'), TERM='xterm')
    env.pop('STY', None)
    back = tmp_path / 'back'

    def listed():
        return subprocess.run(['screen', '-ls'], env=env, capture_output=True, text=True).stdout

    subprocess.run(['screen', '-dmS', 'night', 'sleep', '60'], env=env, check=True)
    attach = shlex.join(m.Screens().attach_command('night'))
    pid, fd = pty.fork()
    if pid == 0:  # the manager's screen, in a terminal, attaching to the night's as the TUI does
        os.execvpe('screen', ['screen', '-S', 'manager', 'sh', '-c', f'{attach}; touch {back}; sleep 60'], env)
    try:
        assert pump(fd, lambda: '.night\t(Attached)' in listed().replace(' ', '\t'))
        assert m.DETACH_KEYS == 'Ctrl-T d'
        os.write(fd, b'\x14d')
        assert pump(fd, back.exists)  # back in the manager's screen...
        assert os.waitpid(pid, os.WNOHANG) == (0, 0)  # ...which is still attached
    finally:
        for name in ('night', 'manager'):
            subprocess.run(['screen', '-S', name, '-X', 'quit'], env=env, capture_output=True)
        os.close(fd)  # first, or a process exiting with output unread can wait on it forever
        try:
            os.kill(pid, 9)
            os.waitpid(pid, 0)
        except (ProcessLookupError, ChildProcessError):
            pass
