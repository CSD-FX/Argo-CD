#!/usr/bin/env bash
set -euo pipefail

kubectl get ns argocd >/dev/null 2>&1 || kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s || true

echo "Initial admin password (if not ready yet, wait 30-60s):"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "not-ready"
