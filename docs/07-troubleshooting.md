# 07 - Troubleshooting

Start with:

```bash
kubectl get pods -A | grep -E 'myapp|mydb'
kubectl -n mydb describe pod mysql-0
kubectl -n mydb logs mysql-0
kubectl -n myapp logs deploy/web
kubectl get events -n mydb --sort-by=.lastTimestamp | tail -20
```

| Symptom | Likely cause | Fix |
|---|---|---|
| `mysql-0` Pending, PVC Pending | StorageClass does not exist or has the wrong name | `kubectl get storageclass`; fix the class name (see 02-storage.md) |
| PVC Pending with `WaitForFirstConsumer` | normal until the pod is scheduled | check the pod events; for `local-static` check the node hostname in the PV affinity |
| PVC Pending, "exceeded quota" | `mydb` quota (2 PVCs, 10Gi) | raise `quotas.db.requestsStorage` / `base/quotas.yaml` |
| `local-static`: pod unschedulable | node hostname wrong, or `/mnt/mysql-data` missing | `kubectl get nodes -L kubernetes.io/hostname`; `sudo mkdir -p /mnt/mysql-data` |
| MySQL CrashLoop: "data directory has files in it" | datadir is the volume root (contains `lost+found`) | this project already uses `--datadir=/var/lib/mysql/data`; if the PVC was initialised by older manifests, delete the PVC and recreate |
| MySQL CrashLoop: permission denied on the data dir | volume not writable by uid/gid 999 | `fsGroup: 999` is set; for `local-static` check the directory is writable (`sudo chown 999:999 /mnt/mysql-data`) |
| App logs "Access denied for user" | secret passwords differ from the ones the MySQL volume was initialised with | see "Password mismatch" below |
| Pods rejected: `violates PodSecurity "restricted"` | the image/cluster does not satisfy `restricted` | set the `mydb` namespace to `baseline` (Helm `--set namespaces.podSecurity=baseline`, Kustomize `base/namespaces.yaml`) |
| `ImagePullBackOff` on web | private GHCR package | create `ghcr-pull` secret and reference it (see 04-kustomize.md; Helm `app.imagePullSecrets`) |
| web not Ready, `/health/ready` fails | MySQL not ready yet, or NetworkPolicy blocks 3306 | check `mysql-0` is Ready; `make verify` |
| Helm: `invalid ownership metadata` for a Namespace | `myapp`/`mydb` already exist | `--set namespaces.create=false` (or delete the old namespaces) |
| Helm: password changed after `helm template` | `lookup` does not work offline | expected; real installs reuse the existing secret |
| `make verify` says REACHABLE | CNI does not enforce NetworkPolicy | use a CNI that does |
| NodePort times out | firewall / security group, policy CIDR, or `externalTrafficPolicy: Local` with no pod on that node | open TCP 30080; check `expose.allowedCIDRs`; try another node IP |
| Gateway has no ADDRESS | no controller / wrong `gatewayClassName` / no LB provider | `kubectl describe gateway web-gateway`; `kubectl get gatewayclass` |
| Gateway ADDRESS ok but 503/timeout | policy does not allow the controller namespace | set `controllerNamespace` to where the proxy pods run |

## Password mismatch (app cannot log in)

MySQL only reads its root/app password when the data directory is first created. If the secret
changes later, the database keeps the old one.

Option A, data does not matter (lab): wipe and recreate

```bash
make down
make up STORAGE=...
```

Option B, keep the data: put the original passwords back

- Helm: `--set secrets.rootPassword=<old> --set secrets.appPassword=<old>`
- Kustomize: recreate both secrets with the old values
  (`MYSQL_PASSWORD` in `mysql-credentials` and `DB_PASSWORD` in `app-db-credentials` must match).

## Clean slate

```bash
# Helm
cd 01-helm && make down
# Kustomize
cd 02-kustomize && make down STORAGE=<same as up>
# leftovers (local-static): the old database stays on the node, remove it for a truly fresh start:
#   sudo rm -rf /mnt/mysql-data/data
```
