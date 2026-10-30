"""What the manager's tests and each pipeline's own share: a throwaway copy of a pipeline's config with its folders
under a temporary directory, the environment for the fakes in fake_bin/ (the librarian, hera_opm's scripts, and
mail), and fake screens."""
import os
import sys
from pathlib import Path

import toml

TESTS_DIR = Path(__file__).resolve().parent
OPS_DIR = TESTS_DIR.parent
EXAMPLE_CONFIG = TESTS_DIR / 'example_pipeline' / 'config.toml'
sys.path.insert(0, str(OPS_DIR))

import manager as m  # noqa: E402


def write_config(root, pipeline_config=EXAMPLE_CONFIG, **manager_settings):
    """A copy of a pipeline's config.toml in root, with every folder under root, its steps' scripts and tomls where
    they are, no host or email, and the given [manager] settings."""
    root = Path(root)
    cfg = toml.load(pipeline_config)
    cfg['paths'].update({key: str(root / key.removesuffix('_root')) for key in m.ROOTS})
    for step in m.Config.load(pipeline_config).steps:
        settings = cfg.setdefault('steps', {}).setdefault(step.name, {})
        settings['script'] = str(step.script)
        if step.toml:
            settings['toml'] = str(step.toml)
    cfg['workflow'].pop('toml', None)  # every step now names its own
    cfg['manager'].update({'poll_seconds': 1, 'session_prefix': 'p2test', 'required_host': '', 'email': '',
                           **manager_settings})
    path = root / 'config.toml'
    path.write_text(toml.dumps(cfg))
    (root / 'nights.txt').touch()
    return path


def fake_env(config_path, **extra):
    """The environment the step scripts need to run here: the fakes on the PATH, and no conda check."""
    return dict(os.environ, PATH=f'{TESTS_DIR / "fake_bin"}:{os.environ["PATH"]}', OPS_CONFIG=str(config_path),
                OPS_SKIP_CONDA_CHECK='1', **extra)


class FakeScreens:
    """Records launches instead of starting screens; tests say which sessions are alive."""

    def __init__(self):
        self.alive = set()
        self.launched = []
        self.interrupted = []

    def live_sessions(self):
        return set(self.alive)

    def launch(self, name, command, env):
        self.launched.append((name, command, env))
        self.alive.add(name)

    def attach_command(self, name):
        return ['true']

    def interrupt(self, name):
        self.interrupted.append(name)
