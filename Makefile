.PHONY: k3s-install k3s-uninstall addons-fix argocd-install argocd-expose kube-info app-apply app-delete

SHELL := /bin/bash
K3S_SUDO ?= sudo

k3s-install:
	$(K3S_SUDO) bash scripts/install_k3s_ubuntu.sh

k3s-uninstall:
	$(K3S_SUDO) /usr/local/bin/k3s-uninstall.sh || true

addons-fix:
	bash scripts/fix_k3s_addon_images.sh

argocd-install:
	bash scripts/install_argocd.sh

argocd-expose:
	bash scripts/expose_argocd.sh

kube-info:
	kubectl version --short && kubectl get nodes -o wide && kubectl get pods -A

app-apply:
	kubectl apply -k k8s/app

app-delete:
	kubectl delete -k k8s/app || true
