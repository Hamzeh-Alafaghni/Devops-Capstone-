#!/usr/bin/env python3
"""Record real CLI verification output as an asciicast v2 terminal demo."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

root = Path(__file__).resolve().parent.parent
os.chdir(root)
region = os.environ.get('AWS_REGION', 'us-east-1')
instance = os.environ['CONTROL_PLANE_ID']
os.environ['BASE_URL']  # Require the intended deployment explicitly.
destination = Path(os.environ.get('DEMO_PATH', 'docs/evidence/demo.cast'))
destination.parent.mkdir(parents=True, exist_ok=True)
started = time.monotonic()
recording = destination.open('w')
recording.write(json.dumps({'version': 2, 'width': 140, 'height': 40,
                           'timestamp': int(time.time()), 'title': 'Marketly live DevOps verification'}) + '\n')


def emit(value):
    print(value, end='', flush=True)
    recording.write(json.dumps([round(time.monotonic() - started, 3), 'o', value.replace('\n', '\r\n')]) + '\n')
    recording.flush()


def run(args):
    emit('$ ' + shlex.join(args) + '\n')
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in process.stdout:
        emit(line)
    if process.wait():
        raise SystemExit('Command failed; recording retained for diagnosis.')


run(['gh', 'run', 'list', '--limit', '6'])
run([sys.executable, 'tests/smoke.py'])
remote = '''set -eu
date -u
k3s kubectl get nodes -o wide
k3s kubectl -n marketly get deployments,pods,hpa
k3s kubectl -n marketly get deployments -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'
k3s kubectl -n marketly describe hpa orders-service
systemctl list-timers marketly-maintenance.timer --no-pager
'''
emit('$ AWS SSM: inspect nodes, deployments, exact image tags, HPA and maintenance timer\n')
payload = {'InstanceIds': [instance], 'DocumentName': 'AWS-RunShellScript',
           'Parameters': {'commands': [remote]}}
response = json.loads(subprocess.check_output(['aws', 'ssm', 'send-command', '--region', region,
                                              '--cli-input-json', json.dumps(payload), '--output', 'json'], text=True))
command_id = response['Command']['CommandId']
for _ in range(24):
    time.sleep(5)
    attempt = subprocess.run(['aws', 'ssm', 'get-command-invocation', '--region', region,
                              '--command-id', command_id, '--instance-id', instance,
                              '--output', 'json'], capture_output=True, text=True)
    if attempt.returncode:
        continue
    result = json.loads(attempt.stdout)
    if result['Status'] in ['Pending', 'InProgress', 'Delayed']:
        continue
    emit(result.get('StandardOutputContent', ''))
    emit(result.get('StandardErrorContent', ''))
    if result['Status'] != 'Success':
        raise SystemExit('SSM verification failed: ' + result['Status'])
    break
else:
    raise SystemExit('SSM verification timed out: ' + command_id)
emit('Live verification complete.\n')
recording.close()
print('Saved', destination)
