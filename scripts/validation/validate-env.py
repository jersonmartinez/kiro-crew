#!/usr/bin/env python3
"""Validate the public/local Compose environment contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"line {number}: expected KEY=VALUE")
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError(f"line {number}: invalid variable name {key!r}")
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key] = value
    return values


def require(values: dict[str, str], key: str) -> str:
    value = values.get(key, "")
    if not value:
        raise ValueError(f"{key} must not be empty")
    return value


def positive_int(values: dict[str, str], key: str) -> None:
    value = require(values, key)
    if not value.isdigit() or int(value) <= 0:
        raise ValueError(f"{key} must be a positive integer")


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else ".env.example")
    try:
        values = load_env(path)
        values.setdefault("KIRO_A_PORT", "5476")
        values.setdefault("KIRO_B_PORT", "5477")
        values.setdefault("DOCKER_SOCKET_GID", "0")
        values.setdefault("KIROCREW_ACP_INIT_TIMEOUT_SECS", "120")
        values.setdefault("KIROCREW_SOURCE_PROVIDER_TIMEOUT_SECS", "120")
        values.setdefault("KIROCREW_MASK_MAX_DEPTH", "4")
        values.setdefault("KIROCREW_MASK_TMPFS_SIZE", "1g")
        require(values, "PROJECTS_BASE")
        image = require(values, "KIROCREW_IMAGE")
        if path.name == ".env.example" and "@sha256:" not in image:
            raise ValueError("KIROCREW_IMAGE must use a sha256 digest in .env.example")
        positive_int(values, "KIRO_A_PORT")
        positive_int(values, "KIRO_B_PORT")
        if values["KIRO_A_PORT"] == values["KIRO_B_PORT"]:
            raise ValueError("KIRO_A_PORT and KIRO_B_PORT must be different")
        for key in (
            "DOCKER_SOCKET_GID",
            "KIROCREW_ACP_INIT_TIMEOUT_SECS",
            "KIROCREW_SOURCE_PROVIDER_TIMEOUT_SECS",
            "KIROCREW_MASK_MAX_DEPTH",
        ):
            value = require(values, key)
            if not value.isdigit():
                raise ValueError(f"{key} must be an integer")
        if not re.fullmatch(r"[0-9]+[kmgt]", require(values, "KIROCREW_MASK_TMPFS_SIZE"), re.I):
            raise ValueError("KIROCREW_MASK_TMPFS_SIZE must look like 1g, 512m, or 2t")
        print(f"env-validation-ok: {path}")
        return 0
    except (OSError, ValueError) as error:
        print(f"env-validation-failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
