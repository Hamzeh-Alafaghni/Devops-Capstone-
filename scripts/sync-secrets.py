#!/usr/bin/env python3
"""Sync RDS credentials and preserve the cluster's signing key without logging secrets."""
import base64
import json
import os
import secrets
import subprocess
import sys
from urllib.parse import quote

def output(args):
    return subprocess.check_output(args, text=True)

region = os.environ['AWS_REGION']
secret_arn = os.environ['DATABASE_SECRET_ARN']
host = os.environ['DATABASE_HOST']
value = json.loads(output(['aws', 'secretsmanager', 'get-secret-value', '--region', region,
                          '--secret-id', secret_arn, '--query', 'SecretString', '--output', 'text']))
existing = output(['kubectl', '-n', 'marketly', 'get', 'secret', 'app-secrets', '--ignore-not-found', '-o', 'json'])
shared = (json.loads(existing)['data']['SHARED_SECRET'] if existing else
          base64.b64encode(secrets.token_hex(32).encode()).decode())
url = f"postgresql://{quote(value['username'], safe='')}:{quote(value['password'], safe='')}@{host}:5432/marketly?sslmode=require"
manifest = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': 'app-secrets', 'namespace': 'marketly'},
            'type': 'Opaque', 'data': {'SHARED_SECRET': shared, 'DATABASE_URL': base64.b64encode(url.encode()).decode()}}
changed = not existing or json.loads(existing)['data'] != manifest['data']
subprocess.run(['kubectl', 'apply', '--server-side', '--field-manager=marketly-secrets', '-f', '-'],
               input=json.dumps(manifest), text=True, check=True, stdout=subprocess.DEVNULL)
print('Application secrets synchronized.')

if changed and '--restart' in sys.argv:
    subprocess.run(['kubectl', '-n', 'marketly', 'rollout', 'restart',
                    'deployment/auth-service', 'deployment/catalog-service', 'deployment/orders-service'], check=True)
