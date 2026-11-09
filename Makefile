MAKES-LOCAL-DIR := $(CURDIR)/.cache
M := .cache/makes
MAKES-REPO ?= https://github.com/makeplus/makes
MAKES-COMMIT := a73d8339c80b4481803cf722fb49e42359e04e79

ifeq (,$(wildcard $M/init.mk))
$(shell mkdir -p $(dir $M) && git clone -q $(MAKES-REPO) $M && \
  git -C $M checkout -q $(MAKES-COMMIT))
endif

include $M/init.mk
MAKES-NO-CLEAN := true
include $M/go.mk

HELM-REPO ?= https://github.com/kustohelm/helm.git
HELM-BRANCH ?= kustohelm-fresh-start
KUSTOMIZE-REPO ?= https://github.com/kubernetes-sigs/kustomize.git
KUSTOMIZE-COMMIT := ace3fedfc2e404f835668905cffebcc62f3b8a39
KUSTOHELM := $(LOCAL-BIN)/helm
VALUES ?= examples/my-values.yaml
SHELL-NAME := kustohelm
SHELL-DEPS += build
MAKES-CLEAN += $(KUSTOHELM)

export HELM_CONFIG_HOME := $(LOCAL-ROOT)/helm/config
export HELM_CACHE_HOME := $(LOCAL-ROOT)/helm/cache
export HELM_DATA_HOME := $(LOCAL-ROOT)/helm/data

repos/helm/.git:
	git clone --single-branch --branch $(HELM-BRANCH) $(HELM-REPO) repos/helm

repos/kustomize/.git:
	git clone $(KUSTOMIZE-REPO) repos/kustomize
	git -C repos/kustomize checkout $(KUSTOMIZE-COMMIT)

build: $(GO) repos/helm/.git repos/kustomize/.git
	cd repos/helm && $(GO) build -o $(KUSTOHELM) ./cmd/helm

check: $(GO) repos/helm/.git repos/kustomize/.git
	cd repos/helm && $(GO) test ./pkg/engine ./pkg/chart/v2/...

render: build
	$(KUSTOHELM) template home examples/home -f $(VALUES)

ifneq (,$(filter demo demo-% k3d-% shell bash zsh shell-env,$(MAKECMDGOALS)))
K3D-CLUSTER-NAME := kustohelm-demo
K3D-CREATE-OPTIONS := --kubeconfig-update-default=false \
  --kubeconfig-switch-context=false
include $M/k3d.mk
# Honor Docker Desktop contexts instead of requiring /var/run/docker.sock.
K3D-DOCKER-RUNNING := $(shell docker info >/dev/null 2>&1 && echo true)

export KUBECONFIG := $(K3D-KUBECONFIG)

demo: build $(K3D-CLUSTER)
	$(KUSTOHELM) upgrade --install home examples/home \
	  -f $(VALUES) --namespace home --create-namespace \
	  --wait --timeout 180s
	$(KUSTOHELM) status home --namespace home
	$(KUSTOHELM) get manifest home --namespace home

demo-delete: k3d-delete
endif

include $M/clean.mk
include $M/shell.mk
