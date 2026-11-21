#!/usr/bin/env python3
"""Convert downloaded native Firebase configs into Dart build-time options.
No credentials are uploaded and no database is modified.
"""
import argparse
import json
import plistlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--android', type=Path, help='Path to google-services.json')
parser.add_argument('--ios', type=Path, help='Path to GoogleService-Info.plist')
args = parser.parse_args()
if not args.android and not args.ios:
    parser.error('Provide --android and/or --ios configuration downloaded from Firebase Console.')
output = {}
if args.android:
    config = json.loads(args.android.read_text())
    if config['project_info']['project_id'] != 'ikill-4e337':
        raise SystemExit('Expected Firebase project ikill-4e337; refusing a different backend.')
    clients = [c for c in config['client'] if c['client_info']['android_client_info']['package_name'] == 'net.ikill.app']
    if not clients:
        raise SystemExit('Register an Android app with package net.ikill.app first.')
    output['FIREBASE_ANDROID_APP_ID'] = clients[0]['client_info']['mobilesdk_app_id']
    output['FIREBASE_API_KEY'] = clients[0]['api_key'][0]['current_key']
if args.ios:
    with args.ios.open('rb') as file:
        config = plistlib.load(file)
    if config['PROJECT_ID'] != 'ikill-4e337' or config['BUNDLE_ID'] != 'net.ikill.app':
        raise SystemExit('Expected Firebase project ikill-4e337 and iOS bundle net.ikill.app.')
    output['FIREBASE_IOS_APP_ID'] = config['GOOGLE_APP_ID']
    output['FIREBASE_IOS_API_KEY'] = config['API_KEY']
path = root / 'firebase_build.json'
if path.exists():
    previous = json.loads(path.read_text())
    previous.update(output)
    output = previous
path.write_text(json.dumps(output, indent=2) + '\n')
print('Wrote firebase_build.json. Run: flutter run --dart-define-from-file=firebase_build.json')
