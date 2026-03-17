from __future__ import annotations

import argparse
import sys

from .core import run_codex


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="codex-profile-manager-runner", add_help=False)
    parser.add_argument("--account", required=True)
    parser.add_argument("args", nargs=argparse.REMAINDER)
    return parser


def main() -> int:
    parser = build_parser()
    namespace = parser.parse_args()
    args = list(namespace.args)
    if args and args[0] == "--":
        args = args[1:]
    return run_codex(namespace.account, args)


if __name__ == "__main__":
    raise SystemExit(main())
