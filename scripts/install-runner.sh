#!/usr/bin/env bash
# Run as root on the new control plane. The registration token is a temporary
# SSM SecureString, never part of user-data, the checkout, or command output.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root on the control plane.' >&2; exit 1; }
: "${AWS_REGION:?Set AWS_REGION}"
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY to owner/repository}"
: "${RUNNER_VERSION:?Set the official runner release version}"
: "${RUNNER_SHA256:?Set the official Linux x64 archive checksum}"
: "${RUNNER_TOKEN_PARAMETER:?Set the temporary SSM SecureString parameter name}"
[[ "$RUNNER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$RUNNER_SHA256" =~ ^[a-f0-9]{64}$ ]]
cloud-init status --wait
k3s kubectl wait --for=condition=Ready nodes --all --timeout=300s
dnf install -y git libicu
id runner >/dev/null 2>&1 || useradd --create-home runner
install -d -m 700 -o runner -g runner /home/runner/.kube
install -m 600 -o runner -g runner /etc/rancher/k3s/k3s.yaml /home/runner/.kube/config
install -d -m 755 -o runner -g runner /home/runner/actions-runner
cd /home/runner/actions-runner
if [[ -f .runner ]]; then
  echo 'Runner already registered; refusing to overwrite its registration.'
  exit 0
fi
curl --retry 5 -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" -o /tmp/marketly-runner.tar.gz
printf '%s  %s\n' "$RUNNER_SHA256" /tmp/marketly-runner.tar.gz | sha256sum -c -
tar -xzf /tmp/marketly-runner.tar.gz
chown -R runner:runner /home/runner/actions-runner
token=$(aws ssm get-parameter --region "$AWS_REGION" --name "$RUNNER_TOKEN_PARAMETER" --with-decryption --query Parameter.Value --output text)
runuser -u runner -- ./config.sh --unattended --url "https://github.com/$GITHUB_REPOSITORY" \
  --token "$token" --name "marketly-$(hostname)" --labels marketly --work _work
unset token
./svc.sh install runner
./svc.sh start
rm /tmp/marketly-runner.tar.gz
