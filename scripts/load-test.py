#!/usr/bin/env python3
"""Bounded authenticated read load for the HPA demo; no orders are placed."""
import concurrent.futures
import json
import os
import time
import urllib.request
import uuid

base = os.environ['BASE_URL'].rstrip('/')
duration = int(os.environ.get('DURATION_SECONDS', '180'))
workers = int(os.environ.get('CONCURRENCY', '24'))
if not 1 <= duration <= 600 or not 1 <= workers <= 100:
    raise SystemExit('Use duration 1–600 seconds and concurrency 1–100.')
body = json.dumps({'username': 'load_' + uuid.uuid4().hex[:12], 'password': uuid.uuid4().hex}).encode()
req = urllib.request.Request(base + '/api/auth/register', data=body,
                             headers={'Content-Type': 'application/json'})
with urllib.request.urlopen(req, timeout=15) as response:
    token = json.load(response)['token']
deadline = time.monotonic() + duration


def load(_):
    success = failure = 0
    while time.monotonic() < deadline:
        req = urllib.request.Request(base + '/api/orders', headers={'Authorization': 'Bearer ' + token})
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                response.read()
                success += 1
        except Exception:
            failure += 1
    return success, failure


print(f'Running {workers} readers for {duration}s; watch the orders-service HPA.', flush=True)
with concurrent.futures.ThreadPoolExecutor(workers) as pool:
    counts = list(pool.map(load, range(workers)))
success, failure = map(sum, zip(*counts))
print(f'Completed: {success} successful requests, {failure} failures; HPA changes must be observed separately.')
if failure:
    raise SystemExit(1)
