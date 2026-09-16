#!/bin/bash
set -euo pipefail
# NAT/user-data may still be initializing when this node boots.
for attempt in $(seq 1 30); do
  dnf install -y --allowerasing curl awscli-2 && break
  sleep 10
done
command -v aws
command -v curl
mkdir -p /etc/rancher/k3s
chmod 700 /etc/rancher/k3s
for attempt in $(seq 1 60); do
  TOKEN=$(aws ssm get-parameter --region '${region}' --name '${token_parameter}' --with-decryption --query Parameter.Value --output text) && break
  sleep 10
done
test -n "$TOKEN"
printf 'token: "%s"\n' "$TOKEN" > /etc/rancher/k3s/config.yaml
chmod 600 /etc/rancher/k3s/config.yaml
unset TOKEN
cat >> /etc/rancher/k3s/config.yaml <<'CONFIG'
secrets-encryption: true
write-kubeconfig-mode: "0600"
disable:
  - servicelb
CONFIG
curl --retry 10 -fsSL https://get.k3s.io -o /tmp/install-k3s.sh
INSTALL_K3S_VERSION='${k3s_version}' sh /tmp/install-k3s.sh server
