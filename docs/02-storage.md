# 02 - MySQL storage (local or Longhorn)

MySQL stores its data on a PVC created by the StatefulSet (`data-mysql-0`, 5Gi by default).
Which StorageClass backs it is the only thing that changes between the options.

## Choose

| Option | StorageClass | Survives pod restart | Survives node loss | Needs |
|---|---|---|---|---|
| `local` | `local-path` (dynamic) | yes | no (data lives on one node) | a local-path provisioner |
| `local-static` | `local-storage` (no-provisioner) + 1 PV | yes | no | directory on the node + node hostname |
| `longhorn` | `longhorn` | yes | yes (replicated, default 3) | Longhorn installed, enough nodes for replicas |

Rule of thumb: `longhorn` for anything you care about, `local` for quick labs,
`local-static` when you want a fixed host path and no provisioner.

## local (dynamic)

Uses an existing StorageClass, default name `local-path`. Check it exists:

```bash
kubectl get storageclass
```

If yours has another name: Helm `--set storage.local.storageClassName=<name>`
(empty string = cluster default), Kustomize edit `overlays/local/kustomization.yaml`.

## local-static

Creates a StorageClass (`no-provisioner`, `WaitForFirstConsumer`, reclaim `Retain`) and one PV pinned to a node.

On the node:

```bash
sudo mkdir -p /mnt/mysql-data
```

Find the hostname label value:

```bash
kubectl get nodes -L kubernetes.io/hostname
```

- Helm: `values-local-static.yaml` -> `storage.local.static.nodeName`, `path`
- Kustomize: `overlays/local-static/storage.yaml` -> `values:` (hostname), `local.path`, `capacity.storage`

The PV capacity must be >= the PVC request (`storage.size`, default 5Gi).
The deploy refuses to run while `CHANGE_ME_NODE_HOSTNAME` is still in place.

## longhorn

Longhorn must already be installed (`kubectl get storageclass longhorn`). Default class name: `longhorn`.

Dedicated StorageClass (for example 1 replica on a single-node lab):

```bash
# Helm
--set storage.longhorn.createStorageClass=true \
--set storage.longhorn.storageClassName=longhorn-mysql \
--set storage.longhorn.numberOfReplicas=1
```

Kustomize: uncomment `storageclass-custom.yaml` in `overlays/longhorn/kustomization.yaml`
and change the patch value to `longhorn-mysql`.

## Size and quota

`mydb` has a ResourceQuota of 2 PVCs and 10Gi total. If you raise the volume size above that:

- Helm: `--set storage.size=20Gi --set quotas.db.requestsStorage=30Gi`
- Kustomize: edit `base/quotas.yaml` and the PVC size in `base/mysql/statefulset.yaml`

For `local-static`, also raise the PV capacity.

## Switching storage

Data is not moved. Switching means a new, empty database:

```bash
make down            # removes the release / namespaces (and the PVC)
make up STORAGE=...  # new storage option
```

To keep data, back it up first (for example `mysqldump` from the pod) and restore afterwards.

## What happens to the data on uninstall

| Option | After `make down` |
|---|---|
| `local` | volume deleted (provisioner reclaim policy is usually Delete) |
| `local-static` | the PV object is removed with the release, but the files stay in `/mnt/mysql-data/data` on the node; `sudo rm -rf` it to start clean (a re-install would otherwise reuse the old database) |
| `longhorn` | volume deleted when reclaim policy is `Delete` (default); use `Retain` to keep it |

## Why `--datadir=/var/lib/mysql/data`

A freshly formatted ext4 volume has a `lost+found` directory at its root. MySQL refuses to initialise
a data directory that already contains files, so the pod would crash-loop on Longhorn. Using a
sub-folder as the datadir works on every storage type.
