# 04 - Kustomize (`02-kustomize/`)

```
02-kustomize/
├── base/                         original manifests (storage-agnostic)
│   ├── kustomization.yaml        resources + image (ghcr.io/0nistack/python-mysql-lab:latest)
│   ├── namespaces.yaml  quotas.yaml  network-policies.yaml
│   ├── app/    configmap, deployment, service, serviceaccount
│   └── mysql/  statefulset, service, serviceaccount
├── overlays/                     pick ONE
│   ├── local/                    patch: storageClassName local-path
│   ├── local-static/             + StorageClass/PV, patch: local-storage
│   └── longhorn/                 patch: longhorn (+ optional custom StorageClass)
├── expose/                       optional external access (apply separately)
│   ├── nodeport/
│   └── gateway/
├── scripts/create-secrets.sh
└── Makefile
```

The base has no `storageClassName`; each overlay adds it with a JSON patch.

## Commands

```bash
cd 02-kustomize

make up STORAGE=longhorn        # or local / local-static
make build STORAGE=longhorn     # print rendered YAML only
make status
make verify
make down STORAGE=longhorn

make expose EXPOSE=nodeport     # optional, see 05-expose.md
make unexpose EXPOSE=nodeport
```

`make up` does, in order:

1. `kubectl apply -f base/namespaces.yaml`
2. `scripts/create-secrets.sh` (skips if the secrets already exist)
3. `kubectl apply -k overlays/<STORAGE>`
4. waits for the MySQL StatefulSet and the web Deployment

## Change the image tag

```bash
cd base
kustomize edit set image ghcr.io/0nistack/python-mysql-lab=ghcr.io/0nistack/python-mysql-lab:v1.0.0
```

## Private GHCR package

```bash
kubectl -n myapp create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<user> --docker-password=<PAT with read:packages>
```

Then add `imagePullSecrets: [{name: ghcr-pull}]` under `spec.template.spec` in `base/app/deployment.yaml`.

## Other edits

| Want to change | Edit |
|---|---|
| Volume size | `base/mysql/statefulset.yaml` (+ `base/quotas.yaml` if > 10Gi) |
| Replicas, resources | `base/app/deployment.yaml` |
| Ingress controller namespace | `base/network-policies.yaml` (`ingress-nginx`) |
| Pod Security level | `base/namespaces.yaml` |
| DB name / user | `base/app/configmap.yaml` and `scripts/create-secrets.sh` |

## Secrets

Kustomize does not generate random values, so `scripts/create-secrets.sh` creates
`mysql-credentials` and `app-db-credentials` with random passwords directly in the cluster
(nothing in git). It is safe to re-run; it keeps existing secrets because the MySQL volume was
initialised with them.
