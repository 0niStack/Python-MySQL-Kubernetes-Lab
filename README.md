# Python-MySQL-Lab on Kubernetes (Helm + Kustomize)

FastAPI + SQLAlchemy app on MySQL 8.4, deployed with **Helm** (`01-helm`) or **Kustomize** (`02-kustomize`).

- Image: `ghcr.io/0nistack/python-mysql-lab:latest`
- Source app: https://github.com/0niStack/Python-MySQL-Lab (this is its `k8s/` folder, packaged two ways)
- MySQL accepts traffic **only from the app** (NetworkPolicy), runs non-root (Pod Security `restricted`)
- MySQL storage is your choice: **local** or **Longhorn**
- Optional external access by IP and port: **NodePort** or **Gateway API**

## Layout

```
.
├── README.md                    you are here
├── docs/                        full documentation (index below)
├── scripts/
│   └── verify-network-policy.sh   proves only the app can reach MySQL (used by both)
├── 01-helm/
│   ├── python-mysql-lab/          the chart
│   ├── values-local.yaml  values-local-static.yaml  values-longhorn.yaml      storage
│   ├── values-expose-nodeport.yaml  values-expose-gateway.yaml                 external access
│   └── Makefile
└── 02-kustomize/
    ├── base/                      storage-agnostic manifests
    ├── overlays/{local,local-static,longhorn}/                                 storage
    ├── expose/{nodeport,gateway}/                                              external access
    ├── scripts/create-secrets.sh
    └── Makefile
```

## Pick your options

| | Options |
|---|---|
| Tool | `01-helm` or `02-kustomize` (same result, use one) |
| MySQL storage | `local` (local-path) / `local-static` (PV pinned to a node) / `longhorn` |
| External access | none (default) / `nodeport` / `gateway` |

## Quick start

### Helm

```bash
cd 01-helm
make up STORAGE=longhorn                               # or: local
make up STORAGE=local-static NODE=<node-hostname>      # needs: sudo mkdir -p /mnt/mysql-data on that node
make up STORAGE=longhorn EXPOSE=nodeport               # + http://<node-ip>:30080
```

### Kustomize

```bash
cd 02-kustomize
make up STORAGE=longhorn                               # or: local / local-static (edit overlays/local-static/storage.yaml first)
make expose EXPOSE=nodeport                            # optional, http://<node-ip>:30080
```

### Check it

```bash
make status
kubectl -n myapp port-forward svc/web 8000:80
curl localhost:8000/health/ready
curl localhost:8000/items
make verify              # outside pod blocked, app pod can connect
make down                # remove everything (Kustomize: make down STORAGE=<same as up>)
```

## Make cheat sheet

| Command | `01-helm` | `02-kustomize` |
|---|---|---|
| Deploy | `make up STORAGE=... [EXPOSE=...] [NODE=...] [TAG=...]` | `make up STORAGE=...` |
| Print YAML | `make template STORAGE=...` | `make build STORAGE=...` |
| Lint | `make lint STORAGE=...` | - |
| Open to outside | `EXPOSE=` on `make up` | `make expose EXPOSE=...` / `make unexpose` |
| Status | `make status` | `make status` |
| NetworkPolicy test | `make verify` | `make verify` |
| Remove | `make down` | `make down STORAGE=...` |

`STORAGE` = `local` \| `local-static` \| `longhorn`, `EXPOSE` = `nodeport` \| `gateway`.

## Documentation

| Doc | Content |
|---|---|
| [docs/01-architecture.md](docs/01-architecture.md) | objects, traffic flow, security controls, what differs from the original `k8s/` |
| [docs/02-storage.md](docs/02-storage.md) | local vs local-static vs Longhorn, sizing, switching, why `--datadir` |
| [docs/03-helm.md](docs/03-helm.md) | chart layout, commands, all important values |
| [docs/04-kustomize.md](docs/04-kustomize.md) | base/overlays, commands, image tag, secrets |
| [docs/05-expose.md](docs/05-expose.md) | NodePort and Gateway API access by IP and port |
| [docs/06-testing.md](docs/06-testing.md) | curl tests (inside/outside), NetworkPolicy proof, persistence test |
| [docs/07-troubleshooting.md](docs/07-troubleshooting.md) | symptom -> cause -> fix table, password mismatch, clean slate |

## Requirements

- `kubectl` pointing at your cluster; `helm` (for 01) or `kubectl kustomize` (for 02)
- A CNI that enforces NetworkPolicy (Calico, Cilium, Canal, ...)
- Storage: a `local-path` provisioner, **or** a node directory (`local-static`), **or** Longhorn installed
- External access: open TCP 30080 (NodePort), **or** Gateway API CRDs + controller
- Private GHCR package: an image pull secret (see [docs/04-kustomize.md](docs/04-kustomize.md))

## Good to know

- The default-deny policies are intentional: the app is reachable only from the ingress-controller
  namespace (default `ingress-nginx`) or through the optional external-access policy.
- Passwords are random and not stored in git. Helm keeps them across upgrades; the Kustomize script
  keeps existing secrets on re-run.
- Switching storage does not move data (see [docs/02-storage.md](docs/02-storage.md)).
- The `mydb` quota allows 2 PVCs / 10Gi in total.
