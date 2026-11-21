#!/usr/bin/env python3
"""Run a build command and expose failure diagnostics as Actions annotations."""
import subprocess
import sys

process = subprocess.Popen(sys.argv[1:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
lines = []
for line in process.stdout:
    print(line, end='', flush=True)
    lines.append(line)
code = process.wait()
if code:
    message = ''.join(lines)[-16000:]
    message = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print(f'::error title=Build command failed::{message}', flush=True)
raise SystemExit(code)
