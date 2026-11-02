"""Phase II's own operations tests run its steps against the fakes of the shared operations tests
(operations/tests/fake_bin/ at the top of this repo), with fake_products.sh standing in for what its makeflow makes."""
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
PIPELINE_CONFIG = HERE.parent / 'config.toml'
PIPELINE_TOML = (HERE.parent.parent / 'analysis' / 'phase_II_analysis.toml').resolve()
TASK_SCRIPTS = PIPELINE_TOML.parent / 'task_scripts'
sys.path.insert(0, str(HERE.parents[5] / 'operations' / 'tests'))
sys.path.insert(0, str(TASK_SCRIPTS))

import support  # noqa: E402


def fake_env(config_path, **extra):
    return support.fake_env(config_path, FAKE_MAKEFLOW_PRODUCTS=str(HERE / 'fake_products.sh'), **extra)


@pytest.fixture
def config_path(tmp_path):
    return support.write_config(tmp_path, PIPELINE_CONFIG)
