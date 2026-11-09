.RECIPEPREFIX := >
# STORAGE: local | local-static | longhorn   (= folder name in overlays/)
STORAGE ?= longhorn

# EXPOSE: nodeport | gateway   (folder name in expose/)
EXPOSE ?= nodeport

.PHONY: build up status down verify expose unexpose

build:
> kubectl kustomize overlays/$(STORAGE)

up:
> kubectl apply -f base/namespaces.yaml
> ./scripts/create-secrets.sh
> kubectl apply -k overlays/$(STORAGE)
> kubectl -n mydb rollout status statefulset/mysql --timeout=300s
> kubectl -n myapp rollout status deployment/web --timeout=180s

status:
> kubectl get pods,svc,networkpolicy -n myapp
> kubectl get pods,svc,pvc,networkpolicy -n mydb
> kubectl get pv | grep -E 'NAME|mydb' || true

down:
> kubectl delete -k overlays/$(STORAGE) --ignore-not-found

# make expose EXPOSE=nodeport     -> http://<node-ip>:30080
# make expose EXPOSE=gateway      -> edit expose/gateway/*.yaml first (class + controller namespace)
expose:
> @! grep -rq CHANGE_ME expose/$(EXPOSE) || { echo "Edit the CHANGE_ME values in expose/$(EXPOSE)/ first"; exit 1; }
> kubectl apply -k expose/$(EXPOSE)
> @kubectl -n myapp get svc,gateway 2>/dev/null | grep -E 'NAME|nodeport|gateway' || true

unexpose:
> kubectl delete -k expose/$(EXPOSE) --ignore-not-found

verify:
> ../scripts/verify-network-policy.sh
