#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
from pathlib import Path


def _load_main():
    module_path = Path(__file__).with_name("sparta.py")
    spec = importlib.util.spec_from_file_location("project_sparta_main", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load SPARTA workflow module from {module_path}.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.main


if __name__ == "__main__":
    _load_main()()
