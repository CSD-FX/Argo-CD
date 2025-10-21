#!/usr/bin/env bash
set -euo pipefail

kubectl -n argocd patch svc argocd-server -p '{"spec": {"type": "NodePort", "ports": [ {"name":"http","port":80,"targetPort":8080,"nodePort":30090}, {"name":"https","port":443,"targetPort":8080,"nodePort":30091} ] }}'

echo "ArgoCD UI: http://<EC2_PUBLIC_IP>:30090"
