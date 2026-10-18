# terraform-proxclus-k8s-apps

Applications for the Talos cluster built by
[terraform-proxclus-k8s-infra](https://github.com/ykantoni/terraform-proxclus-k8s-infra),
deployed and kept in sync by **ArgoCD**. Nothing here is applied by hand or by
Terraform: ArgoCD watches this repo's `main` branch and reconciles the cluster
to it.

## How it's wired

k8s-infra's ArgoCD addon creates one root `Application` (app-of-apps) pointed
at `apps/` in this repo. Every file in `apps/` is itself an `Application`, so:

- **Add an app**: add `apps/<name>.yaml` (plus its values/manifests under
  `<name>/`), push to `main`.
- **Change an app**: edit its values or manifests, push to `main`.
- **Remove an app**: delete `apps/<name>.yaml`, push. Prune is on and every
  child `Application` carries ArgoCD's resources finalizer, so its workloads
  are deleted too — including PVCs.

All apps sync automatically with prune and self-heal: changes made with
`kubectl` drift-revert within minutes. Change things through Git.

**Nothing pushed, nothing deployed.** ArgoCD reads GitHub, not a local
checkout, so local commits have no effect until pushed.

## Layout

| Application | Source | Namespace |
| --- | --- | --- |
| `ollama` | otwld/ollama chart + `ollama/ollama-values.yaml` + `ollama/manifests/` | `ollama` |
| `open-webui` | open-webui chart + `ollama/open-webui-values.yaml` | `ollama` |
| `cnpg-operator` | cloudnative-pg chart | `cnpg-system` |
| `postgres-cnpg` | `postgres-cnpg/manifests/` (a CNPG `Cluster`) | `postgres` |
| `postgres` | `postgres/` (plain StatefulSets) | `postgres-primary`, `postgres-standby` |

Chart-based apps are multi-source `Application`s: the upstream chart, plus
this repo as `$values` for their values file, plus (for ollama) a plain
manifests directory for the objects the chart doesn't make.

## Secrets

This repo is **public**. No credentials go in it. CNPG generates its own
Secrets in-cluster; the plain `postgres` app reads two Secrets you create by
hand (see `postgres` below). The local `postgres/.env.*` files are gitignored.

## Status

```bash
kubectl -n argocd get applications
argocd app list            # after argocd login <argocd-server IP> --insecure
```

## postgres

ArgoCD creates the `postgres-primary`/`postgres-standby` namespaces, but its
StatefulSets stay in `CreateContainerConfigError` until their credential
Secrets exist. Create them once (untracked by ArgoCD, so prune and self-heal
leave them alone):

```bash
for side in primary standby; do
  kubectl -n postgres-$side create secret generic postgres-$side-credentials \
    --from-literal=POSTGRES_DB=app \
    --from-literal=POSTGRES_USER=<user> \
    --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 24)"
done
```

Use the same user and password on both sides if the standby replicates from
the primary with them.

## Platform dependency

Every app depends on the platform at runtime only: the `longhorn` default
StorageClass, Cilium's LoadBalancer pool, and (for ollama) the GPU Operator's
`nvidia` RuntimeClass and `nvidia.com/gpu.present` node label. Nothing here
references k8s-infra's Terraform state.
