"""The manager's own tests run against the toy pipeline in example_pipeline/, with the fakes in fake_bin/."""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from support import FakeScreens, write_config  # noqa: E402


@pytest.fixture
def config_path(tmp_path):
    return write_config(tmp_path)


@pytest.fixture
def screens():
    return FakeScreens()
