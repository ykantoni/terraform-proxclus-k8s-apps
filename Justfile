# Each app is its own Terraform root with its own Justfile; these recipes
# cover the raw-manifest Postgres under postgres/.

# Create the Postgres cluster.
pg-create:
    kubectl apply -f postgres/postgres-primary-standby.yaml

# Destroy the Postgres cluster.
pg-destroy:
    kubectl delete -f postgres/postgres-primary-standby.yaml --ignore-not-found
