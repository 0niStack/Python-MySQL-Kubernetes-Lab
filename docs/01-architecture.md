# 01 - Architecture

Kubernetes packaging (Helm + Kustomize) of
[0niStack/Python-MySQL-Lab](https://github.com/0niStack/Python-MySQL-Lab):
a FastAPI + SQLAlchemy app on MySQL 8.4. Image: `ghcr.io/0nistack/python-mysql-lab:latest`.

## Traffic flow

```
                         (optional, see 05-expose.md)
 outside client ──► NodePort :30080 ─┐
                ──► Gateway  :80   ──┤
 ingress controller ─────────────────┤
                                     ▼
 ┌─────────── namespace myapp ───────────┐        ┌──────── namespace mydb ────────┐
 │  Service web :80 ─► Deployment web x2 │ :3306  │  Service mysql (ClusterIP)     │
 │  (FastAPI, port 8000, non-root)       │ ─────► │  StatefulSet mysql x1          │
 └───────────────────────────────────────┘        │      └─ PVC data ─► StorageClass│
        egress: DNS + mysql only                  └────────────────────────────────┘
                                                   ingress: ONLY app=web from myapp
```

## Objects

| Namespace | Objects |
|---|---|
| `myapp` | Deployment `web` (2 replicas), Service `web`, ConfigMap `app-config`, Secret `app-db-credentials`, ServiceAccount `web`, ResourceQuota/LimitRange, NetworkPolicies |
| `mydb` | StatefulSet `mysql` (1 replica), Service `mysql` (ClusterIP), Secret `mysql-credentials`, ServiceAccount `mysql`, PVC `data-mysql-0`, ResourceQuota/LimitRange, NetworkPolicies |
| cluster | StorageClass / PV (only for `local-static`, or a custom Longhorn class) |

## Security controls

| Control | Where |
|---|---|
| Separate namespaces `myapp` / `mydb` | namespaces |
| Pod Security `restricted` (non-root, no privilege escalation, drop ALL caps, seccomp) | namespace labels + pod specs |
| ResourceQuota + LimitRange | quotas |
| Default-deny in both namespaces | NetworkPolicy `default-deny-all` |
| MySQL reachable only from `app=web` pods in `myapp`, port 3306 | `allow-mysql-from-web-only` |
| Web reachable only from the ingress-controller namespace, port 8000 | `allow-ingress-controller-to-web` |
| Web egress limited to DNS (kube-system) + MySQL | `allow-web-egress` |
| No service-account tokens mounted | ServiceAccounts + pod specs |
| Random DB passwords generated in-cluster, not in git | Helm `secrets.yaml` / `create-secrets.sh` |
| MySQL is ClusterIP only | Service `mysql` |

Opening the app to the outside adds one more policy, `allow-external-to-web` (see `05-expose.md`).

## Differences from the original `k8s/` folder

1. MySQL runs with `--datadir=/var/lib/mysql/data` (ext4 volumes such as Longhorn contain `lost+found`,
   and MySQL refuses to initialise a non-empty data directory).
2. The PVC `storageClassName` comes from the chosen storage option.
3. `create-secrets.sh` no longer regenerates passwords on a re-run.
4. The image is `ghcr.io/0nistack/python-mysql-lab`; the placeholder and the `set image` step are gone.
5. Optional external access (NodePort / Gateway API).

## App endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health/live` | liveness |
| GET | `/health/ready` | readiness (checks the DB) |
| POST | `/items` | create `{"name": "...", "description": "..."}` |
| GET | `/items`, `/items/{id}` | list / read |
| DELETE | `/items/{id}` | delete |
