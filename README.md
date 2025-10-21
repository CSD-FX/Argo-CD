# ArgoCD Auto-Deploy (K3s on EC2)

An end-to-end, commit-driven deployment demo:

- **Auto-deploy**: Edit `k8s/app/index.html` → commit → ArgoCD auto-syncs → K3s rolls out.
- **Kustomize**: `configMapGenerator` creates a hashed ConfigMap so pod template changes on each content update.
- **Public access**: NGINX exposed via NodePort `30080` so you can reach it at your EC2 public IP.

---

## Prerequisites

- EC2 Ubuntu 24.04+ instance
- Security Group inbound:
  - `22/tcp` (SSH)
  - `30090-30091/tcp` (ArgoCD UI)
  - `30080/tcp` (sample app)
- GitHub repo to push this folder to

---

## Folder Structure

- `k8s/app/` – Kustomize app (Deployment mounts ConfigMap, Service NodePort, index.html)
- `k8s/argocd/` – ArgoCD Application and namespace
- `scripts/` – K3s/ArgoCD install, expose UI, and addon image fix
- `Makefile` – convenience targets

---

## 1) Clone & Push this project to Your New GitHub Repo

```bash
git clone https://github.com/CSD-FX/ArgoCD-K3S-GitOPS.git
cd ArgoCD-K3S-GitOPS
```

Edit `k8s/argocd/app.yaml` and set `spec.source.repoURL` to your repo URL.

```bash
git init
git add .
git commit -m ""
git push origin main
```

---

## 2) Install K3s on EC2 and prepare
```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install make -y
```

```bash
sudo make k3s-install
make kube-info
make addons-fix   # repoints CoreDNS/metrics-server/local-path-provisioner to stable registries
kubectl -n kube-system get pods
```
If local-path-provisioner fails
```bash
kubectl -n kube-system set image deploy/local-path-provisioner \
  local-path-provisioner=docker.io/rancher/local-path-provisioner:v0.0.31
kubectl -n kube-system rollout status deploy/local-path-provisioner --timeout=10s
make kube-info
```

---

## 3) Install and expose ArgoCD

```bash
make argocd-install
make argocd-expose
kubectl -n argocd get pods
```

- Get admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```
- Open UI: `http://<EC2_PUBLIC_IP>:30090` (user: `admin`)

---

## 4) Register the repo

- ArgoCD UI → Settings → Repositories → CONNECT → **VIA HTTP/HTTPS**
- Repository URL: `https://github.com/<YOUR_USER>/<YOUR_REPO>.git`
- Connect
   - Don't add any name or project name (Not necessary)
- For private repos: Username = your GitHub user, Password = GitHub PAT with `repo` scope.

---

## 5) Create/Apply the ArgoCD Application

```bash
kubectl apply -f k8s/argocd/namespace.yaml
kubectl apply -f k8s/argocd/app.yaml
kubectl -n argocd annotate application demo-nginx argocd.argoproj.io/refresh=hard --overwrite
```

ArgoCD auto-sync is enabled in the manifest.

---

## 6) Verify and access the app

```bash
kubectl get deploy,svc,pod -l app=demo-nginx -o wide
kubectl describe svc demo-nginx | sed -n '1,80p'
```

- Access from browser: `http://<EC2_PUBLIC_IP>:30080`

---

## 7) Day-2: Auto-deploy content edits

- Edit: `k8s/app/index.html`
- Commit & push:
```bash
git add k8s/app/index.html
git commit -m "content: update landing copy"
git push
```
- ArgoCD will detect a new ConfigMap hash → rewrite Deployment → roll pods automatically.

---

## Troubleshooting

- **ArgoCD Application error: repo not found**: Ensure repo URL in `k8s/argocd/app.yaml` matches the repo you connected in Settings.
- **CoreDNS ImagePullBackOff**: run `make addons-fix`. If CoreDNS still stuck, pre-pull and restart:
```bash
sudo ctr -n k8s.io images pull registry.k8s.io/coredns/coredns:v1.12.3
kubectl -n kube-system delete pod -l k8s-app=kube-dns
```
- **No page on 30080**: Confirm Service exists and NodePort is 30080; ensure SG inbound 30080 open.

---

## Cleanup

```bash
make app-delete
kubectl delete ns argocd --ignore-not-found
sudo make k3s-uninstall
```
