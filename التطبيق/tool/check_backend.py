#!/usr/bin/env python3
"""Fail CI when a removed backend SDK reappears in code or resolved packages."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
old_vendor = 'fire' + 'base'
old_store = 'fire' + 'store'
errors = []
for file in (root / 'lib').rglob('*.dart'):
    if re.search(old_vendor + '|' + old_store, file.read_text(), re.I):
        errors.append(str(file.relative_to(root)))
for name in ['pubspec.yaml', 'pubspec.lock']:
    file = root / name
    if file.exists() and re.search(old_vendor + '|' + old_store, file.read_text(), re.I):
        errors.append(name)
if errors:
    raise SystemExit('Removed backend references found: ' + ', '.join(errors))
print('PASS: runtime sources and dependency manifest contain no removed backend SDK.')
