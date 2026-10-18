# Postgres (primary + standby, CloudNativePG)

A two-instance PostgreSQL cluster (one primary, one streaming-replication
standby) managed by the [CloudNativePG](https://cloudnative-pg.io/) operator.
Deployed by two ArgoCD Applications in `../apps/`:

- `cnpg-operator` — the `cloudnative-pg` chart in `cnpg-system`: the `Cluster`
  CRD and friends, plus the operator, which watches every namespace.
  `ServerSideApply` is on because CNPG's CRDs are too large for client-side
  apply's annotation.
- `postgres-cnpg` — `manifests/cluster.yaml`, a single `Cluster` in
  `postgres`. It syncs with `SkipDryRunOnMissingResource` and retries, so on a
  fresh cluster it simply waits until `cnpg-operator` has registered the CRD.

`spec.instances` (2) is the whole cluster shape: CNPG makes instance 1 the
primary, streams WAL to the rest, and promotes a standby if the primary goes
down. Nothing here hand-configures `primary_conninfo`, replication slots or
`pg_basebackup`.

## Credentials

No password is in Git. CNPG generates two Secrets in `postgres`:

- `postgres-superuser` — the `postgres` superuser
- `postgres-app` — the `app` owner's password, plus a ready-to-use `uri` key
  for the `app` database

## Storage

`storageClass: longhorn` gives every instance 3x Longhorn replication *on top
of* Postgres's own replication between instances. Worth trimming beyond a
smoke test: add a Longhorn StorageClass with `numberOfReplicas: "1"` and point
`spec.storage.storageClass` at it, so CNPG's replication is the only
redundancy.

## Checking it

```bash
kubectl -n postgres get cluster
kubectl -n postgres get pods -l cnpg.io/cluster=postgres
kubectl cnpg status postgres -n postgres   # needs the kubectl-cnpg plugin
```

`instances: 2/2`, with one pod `role: primary` and the other `role: replica`,
means the standby is caught up.
