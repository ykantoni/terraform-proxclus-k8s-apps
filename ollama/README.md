# Ollama + Open WebUI

[Ollama](https://ollama.com/) (via the
[otwld/ollama-helm](https://github.com/otwld/ollama-helm) chart) scheduled onto
a GPU node, with [Open WebUI](https://openwebui.com/) in front of it, so which
model is loaded is a decision made from the browser after it's up. Deployed by
the `ollama` and `open-webui` ArgoCD Applications in `../apps/`.

## What it deploys

- `ollama-values.yaml` — the Ollama server with `ollama.gpu.type: nvidia`, a
  `nodeSelector` on `nvidia.com/gpu.present=true` and `runtimeClassName:
  nvidia`, so it only ever runs on a GPU node. A 20Gi `persistentVolume`
  keeps pulled models across pod restarts. See "Storage".
- `open-webui-values.yaml` — the chat UI, pointed at the Ollama release via
  `ollamaUrls` (its bundled Ollama subchart disabled), exposed as a
  `LoadBalancer`, with its own 2Gi Longhorn PVC for chat history and accounts.

To run Ollama on CPU instead, set `ollama.gpu.enabled: false`,
`runtimeClassName: ""` and `nodeSelector: {}` in `ollama-values.yaml` (slow
beyond small models).

## Choosing a model

Nothing is pulled by default (`ollama.models.pull: []`). Once both apps are
healthy:

```bash
kubectl -n ollama get svc open-webui   # find the LoadBalancer address
```

Open that address, create the first account (it becomes admin), then
**Settings → Admin Settings → Models** to pull any model by name (e.g.
`llama3.1:8b`). That calls Ollama's own `/api/pull`; no redeploy needed. Add
names to `ollama.models.pull` to pre-seed a model at first boot instead.

## Storage

Ollama's model PVC sets no `storageClass`, so it's dynamically provisioned
from the cluster's default StorageClass (`longhorn`). Open WebUI's PVC is on
`longhorn` too.

Longhorn keeps 3 replicas by default, so a 20Gi PVC needs 20Gi free on three
nodes at once. Raise `persistentVolume.size` for bigger models only as far as
the nodes' `disk` in terraform-proxclus-vm-infra allows. Pin a different class
(e.g. a single-replica Longhorn class, since models are re-downloadable) with
`persistentVolume.storageClass`.

A PVC's StorageClass can't be changed in place: switching class on an
existing PVC means deleting it (and its pulled models) and letting ArgoCD
recreate it.
