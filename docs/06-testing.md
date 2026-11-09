# 06 - Testing

## 1. Is everything running?

```bash
make status        # in 01-helm/ or 02-kustomize/
kubectl get pods -n myapp          # web x2 Running 1/1
kubectl get pods,pvc -n mydb       # mysql-0 Running 1/1, PVC Bound
kubectl -n mydb get pvc data-mysql-0 -o wide      # STORAGECLASS column = your storage option
```

## 2. Test the API

### From your workstation (port-forward)

```bash
kubectl -n myapp port-forward svc/web 8000:80
curl localhost:8000/health/ready
curl localhost:8000/items
```

### From the network (NodePort, see 05-expose.md)

```bash
curl http://<node-ip>:30080/health/ready

curl -X POST http://<node-ip>:30080/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"test","description":"hello"}'

curl http://<node-ip>:30080/items
```

### From inside the cluster network

The policy only lets the ingress-controller namespace reach `web`, so run the test pod there
(use your controller's namespace; it must exist):

```bash
kubectl run curl-test -n ingress-nginx --rm -it --restart=Never \
  --image=curlimages/curl --command -- \
  curl -s http://web.myapp.svc.cluster.local/health/ready
```

### From inside a web pod (always works, image has no curl, so Python)

```bash
POD=$(kubectl -n myapp get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl -n myapp exec $POD -- python -c \
  "import urllib.request as u; print(u.urlopen('http://localhost:8000/health/ready').read().decode())"
```

Expected: `/health/ready` returns an OK JSON; `GET /items` returns `[]` first, then your items.

## 3. NetworkPolicy proof

```bash
make verify        # runs ../scripts/verify-network-policy.sh
```

| Test | Expected |
|---|---|
| random pod in `default` -> MySQL 3306 | `OK: blocked` |
| web pod in `myapp` -> MySQL 3306 | `OK: reachable` |

If test 1 says `REACHABLE (policy NOT enforced)`, your CNI does not enforce NetworkPolicy
(use Calico, Cilium, Canal, ...).

Manual check that the outside cannot reach `web` directly:

```bash
kubectl run np-test -n default --rm -it --restart=Never --image=curlimages/curl --command -- \
  curl -sS -m 3 http://web.myapp.svc.cluster.local/health/ready
# expected: timeout
```

## 4. Storage / persistence test

Create data, kill MySQL, check the data is still there:

```bash
curl -X POST localhost:8000/items -H 'Content-Type: application/json' -d '{"name":"persist-me"}'

kubectl -n mydb delete pod mysql-0
kubectl -n mydb rollout status statefulset/mysql --timeout=180s

curl localhost:8000/items          # persist-me must still be listed
```

(keep the port-forward from step 2 running, or restart it after the web pods reconnect)

Where is the data?

```bash
kubectl -n mydb get pvc data-mysql-0
kubectl get pv $(kubectl -n mydb get pvc data-mysql-0 -o jsonpath='{.spec.volumeName}')

# Longhorn
kubectl -n longhorn-system get volumes.longhorn.io
# local-static: on the node
ls /mnt/mysql-data/data
```

## 5. Look inside MySQL

```bash
kubectl -n mydb exec -it mysql-0 -- sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" appdb -e "SHOW TABLES; SELECT * FROM items;"'
```

## 6. Validate the manifests without a cluster

```bash
# Helm
cd 01-helm && make lint STORAGE=longhorn && make template STORAGE=longhorn >/dev/null && echo ok
# Kustomize
cd 02-kustomize && make build STORAGE=longhorn >/dev/null && echo ok
```
