#!/usr/bin/env python3
"""Allow Core + Messaging transport only; forbid every other Firebase backend SDK."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
allowed = {'firebase_core', 'firebase_core_platform_interface', 'firebase_core_web',
           'firebase_messaging', 'firebase_messaging_platform_interface', 'firebase_messaging_web'}
# Core/Messaging are the ONLY exceptions. Auth, document DB, object storage,
# realtime DB, analytics and other vendor SDKs remain prohibited.
def violations(text):
    errors = []
    for name in re.findall(r'\b(?:firebase_[a-z0-9_]+|cloud_firestore|cloud_functions)\b', text):
        if name not in allowed:
            errors.append(name)
    for api in ['Firebase' + 'Auth', 'Firebase' + 'Storage', 'Firebase' + 'Database', 'Firebase' + 'Firestore', 'Cloud' + 'Firestore']:
        if re.search(r'\b' + api + r'\b', text, re.I):
            errors.append(api)
    return errors

# Executable fixture checks ensure the narrow exception never becomes a bypass.
assert not violations("import 'package:firebase_core/firebase_core.dart';")
for forbidden in ['firebase_' + 'auth', 'cloud_' + 'firestore', 'firebase_' + 'storage', 'firebase_' + 'database', 'firebase_' + 'analytics']:
    assert violations(forbidden), forbidden

errors = []
for file in list((root / 'lib').rglob('*.dart')) + [root / 'pubspec.yaml', root / 'pubspec.lock']:
    if not file.exists():
        continue
    text = file.read_text()
    # Imports/manifests only: native manifest flags are not Dart packages.
    found = violations(text)
    if found:
        errors.append(f'{file.relative_to(root)}: {found}')
    if re.search('one' + 'signal', text, re.I):
        errors.append(f'Removed push provider in {file.relative_to(root)}')

repository = root.parent
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=repository).decode().split('\0')
for name in tracked:
    file = repository / name
    if not file.is_file() or file.suffix.lower() not in {'.dart', '.ts', '.js', '.html', '.kts', '.gradle', '.swift'}:
        continue
    if file.name == Path(__file__).name:
        continue
    text = re.sub(r'/\*.*?\*/', '', file.read_text(), flags=re.S)
    text = '\n'.join(line for line in text.splitlines() if not re.match(r'^\s*//', line))
    if violations(text):
        errors.append(f'Forbidden backend runtime API/package: {name}')
    if root in file.parents and re.search('one' + 'signal', text, re.I):
        errors.append(f'Removed provider runtime reference: {name}')

# Optional resolved Android dependency report from Gradle, after APK build.
if len(sys.argv) == 2:
    # Messaging transitive infrastructure (including an optional analytics connector,
    # NOT the analytics SDK); no Auth/document DB/Storage SDK is allowed.
    native_allowed = {'firebase-bom', 'firebase-common', 'firebase-common-ktx', 'firebase-components', 'firebase-annotations',
                      'firebase-messaging', 'firebase-datatransport', 'firebase-measurement-connector', 'firebase-installations', 'firebase-installations-interop',
                      'firebase-iid-interop', 'firebase-encoders', 'firebase-encoders-json', 'firebase-encoders-proto'}
    report = Path(sys.argv[1]).read_text()
    if re.search(r'com\.' + 'one' + 'signal', report, re.I):
        errors.append('Removed provider in native dependencies')
    for artifact in re.findall(r'com\.google\.firebase:([a-z0-9-]+):', report):
        if artifact not in native_allowed:
            errors.append(f'Forbidden native dependency: {artifact}')
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: only Core + Messaging transport allowed; all other backend SDKs prohibited.')
