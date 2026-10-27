#!/usr/bin/env python3
"""Verify untouched upstream sources and apply checked patches to a fresh copy."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2] / "tests/upstream/lua51"
vendor = root / "vendor"
expected = {}
for line in (root / "SHA256SUMS").read_text().splitlines():
    digest, name = line.split("  ", 1)
    expected[name] = digest
actual = {p.relative_to(vendor).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in vendor.rglob("*") if p.is_file()}
if actual != expected:
    raise SystemExit("Vendored Lua 5.1 files differ from SHA256SUMS")
destination = Path(sys.argv[1])
shutil.copytree(vendor, destination)  # Refuse to overwrite any existing copy.
for patch in sorted((root / "patches").glob("*.patch")):
    subprocess.run(["patch", "--batch", "--fuzz=0", "-p1", "-i", str(patch)],
                   cwd=destination, check=True, stdout=subprocess.DEVNULL)
print("Verified upstream checksums and applied compatibility patches")
