#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "Please run as root: sudo bash scripts/install_k3s_ubuntu.sh" >&2
  exit 1
fi

echo "Configuring sysctl for Kubernetes networking..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null || true

if command -v ufw >/dev/null 2>&1; then
  ufw disable || true
fi

export INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644"
curl -sfL https://get.k3s.io | sh -

mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

if ! command -v kubectl >/dev/null 2>&1; then
  ln -sf /usr/local/bin/kubectl /usr/bin/kubectl || true
fi

echo "Waiting for node to be Ready..."
for i in {1..60}; do
  if kubectl get nodes 2>/dev/null | grep -q " Ready "; then
    break
  fi
  sleep 2
done
kubectl get nodes -o wide || true

echo "Waiting for kube-system pods to appear..."
sleep 5
kubectl get pods -n kube-system || true

echo "K3s installed. Next: run 'make addons-fix'"
