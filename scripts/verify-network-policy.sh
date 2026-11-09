#!/usr/bin/env bash
# Proves that only the app can reach MySQL.
set -u
HOST=mysql.mydb.svc.cluster.local

echo "== Test 1: random pod in 'default' namespace -> MySQL (should FAIL/timeout)"
kubectl run np-test-default --rm -i --restart=Never -n default --image=busybox:1.36 \
  --command -- sh -c "nc -zv -w 3 $HOST 3306" && echo "!! REACHABLE (policy NOT enforced)" || echo "OK: blocked"

echo
echo "== Test 2: web pod in 'myapp' -> MySQL (should SUCCEED)"
POD=$(kubectl -n myapp get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl -n myapp exec "$POD" -- python -c \
  "import socket; s=socket.create_connection(('$HOST',3306),3); print('OK: reachable'); s.close()"
