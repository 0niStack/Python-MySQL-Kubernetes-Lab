# 05 - Reach the app by IP and port

By default the app is only reachable inside the cluster. Two optional ways to open it:

| Option | Result | Needs |
|---|---|---|
| `nodeport` | `http://<any-node-ip>:30080` | firewall / security group open on 30080 |
| `gateway` | Gateway API `Gateway` + `HTTPRoute` -> `web:80`, listener port 80 | Gateway API CRDs + a controller |

Both add the NetworkPolicy `allow-external-to-web`, because the default-deny in `myapp` blocks
outside traffic otherwise.

## NodePort

```bash
# Helm
cd 01-helm && make up STORAGE=longhorn EXPOSE=nodeport
# Kustomize
cd 02-kustomize && make expose EXPOSE=nodeport
```

- Restrict who may connect: Helm `expose.allowedCIDRs` (in `values-expose-nodeport.yaml`),
  Kustomize `expose/nodeport/networkpolicy.yaml` (`ipBlock.cidr`, default `0.0.0.0/0`).
- Change the port (30000-32767): `expose.nodePort.port` / `expose/nodeport/service.yaml`.
- `externalTrafficPolicy: Cluster` (default) hides the client IP behind SNAT.
  `Local` keeps it, but only nodes running a web pod answer.
- Cloud / VM firewall: open TCP 30080 (for example the AWS security group).
- Some CNIs (for example Cilium) treat node/host traffic as its own identity; if the policy blocks
  NodePort there, allow the node CIDR explicitly.

## Gateway API

Check the prerequisites:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get gatewayclass            # name goes into className
```

Find the namespace where the controller's proxy pods run (for example `envoy-gateway-system`,
`nginx-gateway`, `kube-system`); it goes into `controllerNamespace`.

```bash
# Helm: edit values-expose-gateway.yaml (className, controllerNamespace, optional address/hostname/port)
cd 01-helm && make up STORAGE=longhorn EXPOSE=gateway
# Kustomize: edit expose/gateway/gateway.yaml and expose/gateway/networkpolicy.yaml
cd 02-kustomize && make expose EXPOSE=gateway
```

Both refuse to run while `CHANGE_ME` placeholders are still there.

Get the IP:

```bash
kubectl -n myapp get gateway web-gateway        # ADDRESS column
kubectl -n myapp describe gateway web-gateway   # Accepted / Programmed
kubectl -n myapp describe httproute web         # Accepted / ResolvedRefs
```

Notes:

- `address` (fixed IP) only works if the controller honours `spec.addresses`.
- `hostname` makes the listener and route match only that Host header.
- If the controller creates its proxy pods inside `myapp`, the `default-deny-all` egress policy
  there also needs an exception for them.

## Remove

```bash
cd 02-kustomize && make unexpose EXPOSE=nodeport
cd 01-helm && make up STORAGE=longhorn            # without EXPOSE: the objects are removed on upgrade
```
