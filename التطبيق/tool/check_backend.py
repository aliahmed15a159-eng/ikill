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

# Inspect tracked runtime/build sources across the whole checkout, not just Dart.
# Historical Markdown/SQL comments are documentation, not executable SDK code.
import subprocess
repository = root.parent
extensions = {'.dart', '.js', '.cjs', '.mjs', '.ts', '.py', '.html', '.css',
              '.json', '.yaml', '.yml', '.xml', '.gradle', '.kts', '.swift',
              '.plist', '.pbxproj', '.sql', '.rules'}
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=repository).decode().split('\0')
for name in tracked:
    if not name:
        continue
    file = repository / name
    if re.search(old_vendor + '|' + old_store, file.name, re.I):
        raise SystemExit('Removed backend filename: ' + name)
    if file.suffix.lower() not in extensions or not file.is_file():
        continue
    try:
        text = file.read_text()
    except UnicodeError:
        continue
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = '\n'.join(line for line in text.splitlines()
                     if not re.match(r'^\s*(//|--|#)', line))
    if re.search(old_vendor + '|' + old_store, text, re.I):
        raise SystemExit('Removed backend runtime/build reference: ' + name)
print('PASS: full repository runtime/build source audit (comments/history excluded).')
