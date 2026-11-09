# 03 - Helm (`01-helm/`)

```
01-helm/
├── python-mysql-lab/            the chart
│   ├── Chart.yaml
│   ├── values.yaml              all defaults, commented
│   └── templates/
│       ├── namespaces.yaml  quotas.yaml  secrets.yaml
│       ├── storage.yaml     (local-static PV/SC, optional Longhorn SC)
│       ├── mysql.yaml  app.yaml  networkpolicies.yaml
│       ├── expose.yaml      (NodePort / Gateway API, off by default)
│       └── _helpers.tpl  NOTES.txt
├── values-local.yaml            storage: local-path
├── values-local-static.yaml     storage: static local PV
├── values-longhorn.yaml         storage: Longhorn
├── values-expose-nodeport.yaml  external access by IP:port
├── values-expose-gateway.yaml   external access via Gateway API
└── Makefile
```

## Commands

```bash
cd 01-helm

make up STORAGE=longhorn
make up STORAGE=local
make up STORAGE=local-static NODE=<node-hostname>
make up STORAGE=longhorn EXPOSE=nodeport          # + external access

make lint STORAGE=longhorn      # helm lint
make template STORAGE=longhorn  # print rendered YAML
make status
make verify                     # NetworkPolicy proof
make down                       # helm uninstall
```

Make variables: `STORAGE` (local | local-static | longhorn), `EXPOSE` (nodeport | gateway),
`NODE`, `TAG` (image tag, default `latest`), `RELEASE`, `HELM_NS`.

Without make:

```bash
helm upgrade --install python-mysql-lab ./python-mysql-lab \
  -f values-longhorn.yaml --wait --timeout 5m
```

## Important values

| Value | Default | Meaning |
|---|---|---|
| `storage.type` | `local` | `local` or `longhorn` |
| `storage.size` | `5Gi` | MySQL volume size |
| `storage.local.mode` | `dynamic` | `dynamic` or `static` |
| `storage.local.storageClassName` | `local-path` | dynamic class |
| `storage.local.static.nodeName/path` | - | static PV placement |
| `storage.longhorn.storageClassName` | `longhorn` | class to use |
| `storage.longhorn.createStorageClass` | `false` | create a dedicated class |
| `app.image.repository/tag` | `ghcr.io/0nistack/python-mysql-lab` / `latest` | image |
| `app.replicas` | `2` | web replicas |
| `app.imagePullSecrets` | `[]` | private GHCR |
| `namespaces.app/db` | `myapp` / `mydb` | namespace names |
| `namespaces.create` | `true` | chart creates the namespaces |
| `namespaces.podSecurity` | `restricted` | PSA level (`baseline` if MySQL is rejected) |
| `namespaces.ingressController` | `ingress-nginx` | namespace allowed to reach web |
| `secrets.create` | `true` | chart manages the two secrets |
| `secrets.rootPassword/appPassword` | `""` | empty = random |
| `quotas.enabled`, `networkPolicies.enabled` | `true` | toggles |
| `expose.mode` | `none` | `none` / `nodePort` / `gateway` |

## Behaviour to know

- **Release namespace:** the release is stored in `default`; the chart creates `myapp` and `mydb` itself.
  If they already exist (or you install with `-n myapp --create-namespace`) set `--set namespaces.create=false`,
  otherwise Helm fails with an ownership error.
- **Passwords:** random on first install and reused on every `helm upgrade` through `lookup`.
  `helm template` and `--dry-run` cannot look up the cluster, so they show throw-away values.
- **Own secrets:** `--set secrets.create=false`, then create `mysql-credentials` (mydb) and
  `app-db-credentials` (myapp) yourself.
- **Uninstall** deletes both namespaces (and the PVC with them).
- **Fail-fast checks:** wrong `storage.type`, missing static `nodeName`, missing Gateway class or
  controller namespace all stop the render with a clear message.
