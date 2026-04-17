#!/usr/bin/env python3
"""Pack the mod into XP-Skills-System.vmz.

Run from the repo root:
    python _tools/repack.py

Godot mod loader expects forward-slash zip entries — PowerShell's
Compress-Archive writes backslashes, which silently breaks path resolution
(the mod ends up inert with no errors). This script uses stdlib zipfile
which writes forward slashes.
"""
import os
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "XP-Skills-System.vmz"

INCLUDE = ["mod.txt", "mods"]
EXCLUDE_SUFFIXES = [".svg"]        # dev-only UV templates
EXCLUDE_NAMES = [".DS_Store", "Thumbs.db"]


def should_skip(path: Path) -> bool:
    if path.name in EXCLUDE_NAMES:
        return True
    return any(path.name.endswith(suf) for suf in EXCLUDE_SUFFIXES)


def main() -> int:
    if OUT.exists():
        OUT.unlink()
    count = 0
    total_bytes = 0
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for top in INCLUDE:
            p = ROOT / top
            if p.is_file():
                if should_skip(p):
                    continue
                z.write(p, arcname=top)
                count += 1
                total_bytes += p.stat().st_size
                continue
            for sub in sorted(p.rglob("*")):
                if sub.is_dir() or should_skip(sub):
                    continue
                arc = sub.relative_to(ROOT).as_posix()  # forward slashes
                z.write(sub, arcname=arc)
                count += 1
                total_bytes += sub.stat().st_size
    print(f"Packed {count} files ({total_bytes / 1e6:.1f} MB source) -> {OUT}")
    print(f"  Archive size: {OUT.stat().st_size / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
