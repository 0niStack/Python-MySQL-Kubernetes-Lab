.RECIPEPREFIX := >
# STORAGE: local | local-static | longhorn
STORAGE  ?= longhorn
RELEASE  ?= python-mysql-lab
HELM_NS  ?= default
TAG      ?= latest
NODE     ?=
# EXPOSE: (empty) | nodeport | gateway
EXPOSE   ?=
CHART    := python-mysql-lab
EXTRA    := $(if $(NODE),--set storage.local.static.nodeName=$(NODE),) $(if $(EXPOSE),-f values-expose-$(EXPOSE).yaml,)

.PHONY: lint template up status down verify

lint:
> helm lint ./$(CHART) -f values-$(STORAGE).yaml --set storage.local.static.nodeName=lint-node

template:
> helm template $(RELEASE) ./$(CHART) -f values-$(STORAGE).yaml --set app.image.tag=$(TAG) $(EXTRA)

# make up STORAGE=longhorn
# make up STORAGE=local
# make up STORAGE=local-static NODE=worker-1
# make up STORAGE=longhorn EXPOSE=nodeport      (edit values-expose-gateway.yaml first for EXPOSE=gateway)
up:
> helm upgrade --install $(RELEASE) ./$(CHART) -n $(HELM_NS) \
>   -f values-$(STORAGE).yaml --set app.image.tag=$(TAG) $(EXTRA) --wait --timeout 5m

status:
> kubectl get pods,svc,networkpolicy -n myapp
> kubectl get pods,svc,pvc,networkpolicy -n mydb
> kubectl get pv | grep -E 'NAME|mydb' || true

down:
> helm uninstall $(RELEASE) -n $(HELM_NS)

verify:
> ../scripts/verify-network-policy.sh
