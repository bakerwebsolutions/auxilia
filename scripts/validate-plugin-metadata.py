#!/usr/bin/env python3
"""Check that host manifests and marketplace entries share plugin metadata."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
IDENTITY_FIELDS = ("name", "description", "version")


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"{path}: cannot read JSON ({exc})") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def compare(label: str, expected: dict[str, Any], actual: dict[str, Any], errors: list[str]) -> None:
    for field in IDENTITY_FIELDS:
        if expected.get(field) != actual.get(field):
            errors.append(f"{label}: {field} differs (expected {expected.get(field)!r}, found {actual.get(field)!r})")


def catalog_entries(catalog: dict[str, Any]) -> list[dict[str, Any]]:
    entries = catalog.get("plugins", [])
    if not isinstance(entries, list):
        raise ValueError("catalog: 'plugins' must be an array")
    return [entry for entry in entries if isinstance(entry, dict) and "name" in entry]


def validate_catalog(path: Path, plugins: dict[str, dict[str, Any]], errors: list[str]) -> None:
    entries = catalog_entries(load_json(path))
    by_name: dict[str, dict[str, Any]] = {}
    for entry in entries:
        name = entry["name"]
        if name in by_name:
            errors.append(f"{path}: duplicate plugin entry {name!r}")
        by_name[name] = entry
        if name in plugins:
            compare(f"{path} [{name}]", plugins[name], entry, errors)
    for name in plugins:
        if name not in by_name:
            errors.append(f"{path}: missing plugin entry {name!r}")


def main() -> int:
    errors: list[str] = []
    plugins: dict[str, dict[str, Any]] = {}
    for manifest in sorted((ROOT / "plugins").glob("*/.claude-plugin/plugin.json")):
        data = load_json(manifest)
        name = data.get("name")
        if not isinstance(name, str):
            errors.append(f"{manifest}: missing string name")
            continue
        plugins[name] = data
        codex_manifest = manifest.parent.parent / ".codex-plugin/plugin.json"
        if codex_manifest.exists():
            compare(str(codex_manifest), data, load_json(codex_manifest), errors)

    claude_catalog = ROOT / ".claude-plugin/marketplace.json"
    if claude_catalog.exists():
        validate_catalog(claude_catalog, plugins, errors)

    for catalog_path in (ROOT / ".agents/plugins/marketplace.json", ROOT / ".codex-plugin/marketplace.json"):
        if not catalog_path.exists():
            continue
        validate_catalog(catalog_path, plugins, errors)

    if errors:
        print("Plugin metadata validation failed:\n" + "\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print(f"Plugin metadata OK ({len(plugins)} Claude manifest(s) checked).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
