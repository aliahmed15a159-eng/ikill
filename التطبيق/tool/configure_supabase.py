#!/usr/bin/env python3
"""Write public client build options from environment; never use a service key."""
import base64
import json
import os
from pathlib import Path
from urllib.parse import urlparse

url = os.environ.get('SUPABASE_URL', '')
key = os.environ.get('SUPABASE_ANON_KEY', '')
parsed = urlparse(url)
if parsed.scheme != 'https' or not parsed.hostname or not key:
    raise SystemExit('Set SUPABASE_URL (HTTPS) and SUPABASE_ANON_KEY (publishable/anon).')
if key.startswith('sb_secret_'):
    raise SystemExit('Privileged keys are forbidden in client builds.')
if key.startswith('ey'):
    try:
        payload = key.split('.')[1]
        role = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))['role']
        if role != 'anon':
            raise ValueError('Not an anonymous key')
    except (ValueError, KeyError, IndexError):
        raise SystemExit('Client JWT must have anon role.')
elif not key.startswith('sb_publishable_'):
    raise SystemExit('Expected an anon JWT or publishable key.')
path = Path(__file__).resolve().parents[1] / 'supabase_build.json'
path.write_text(json.dumps({'SUPABASE_URL': url, 'SUPABASE_ANON_KEY': key,
    'BRAND_SLUG': os.environ.get('BRAND_SLUG', 'ikill')}, indent=2) + '\n')
print('Public Supabase build configuration generated; values not logged.')
