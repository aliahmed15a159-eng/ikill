#!/usr/bin/env python3
"""Verify the original website remains byte-for-byte unchanged."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
args = parser.parse_args()
root = args.source.resolve()
manifest = json.loads((Path(__file__).resolve().parents[1] / 'source-manifest.json').read_text())['sha256']
actual = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in root.rglob('*') if p.is_file() and '.git' not in p.parts}
missing = sorted(set(manifest) - set(actual))
added = sorted(set(actual) - set(manifest))
changed = sorted(p for p in manifest.keys() & actual.keys() if manifest[p] != actual[p])
if missing or added or changed:
    print(json.dumps({'missing': missing, 'added': added, 'changed': changed}, indent=2))
    raise SystemExit(1)
print(f'PASS: all {len(manifest)} original files are unchanged; no files added or removed.')
