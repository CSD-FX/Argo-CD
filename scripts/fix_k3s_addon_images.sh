#!/usr/bin/env bash
set -euo pipefail

ns=kube-system

patch_image() {
  local deploy=$1 container=$2 new_image=$3
  echo "Patching ${deploy}/${container} -> ${new_image}"
  kubectl -n "$ns" set image "deploy/${deploy}" "${container}=${new_image}" --record=true
  if ! kubectl -n "$ns" rollout status "deploy/${deploy}" --timeout=120s; then
    echo "Rollout not ready, pre-pulling and restarting pod..."
    sudo ctr -n k8s.io images pull "$new_image" || true
    kubectl -n "$ns" delete pod -l "$(kubectl -n "$ns" get deploy "$deploy" -o jsonpath='{.spec.selector.matchLabels}' | tr -d '{}' | tr ',' '\n' | awk -F: '{print $1"="$2}' | xargs echo)" || true
    kubectl -n "$ns" rollout status "deploy/${deploy}" --timeout=120s || true
  fi
}

get_img() { kubectl -n "$ns" get deploy "$1" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo ""; }

cur=$(get_img coredns); if [[ -n "$cur" ]]; then tag=${cur##*:}; [[ "$tag" != v* ]] && tag="v$tag"; patch_image coredns coredns "registry.k8s.io/coredns/coredns:${tag}"; fi
cur=$(get_img metrics-server); if [[ -n "$cur" ]]; then tag=${cur##*:}; [[ "$tag" != v* ]] && tag="v$tag"; patch_image metrics-server metrics-server "registry.k8s.io/metrics-server/metrics-server:${tag}"; fi
cur=$(get_img local-path-provisioner); [[ -z "$cur" ]] && cur="rancher/local-path-provisioner:v0.0.31"; tag=${cur##*:}; patch_image local-path-provisioner local-path-provisioner "ghcr.io/rancher/local-path-provisioner:${tag}"

kubectl -n kube-system get pods -o wide
