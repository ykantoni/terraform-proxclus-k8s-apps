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
  keeps pulled models across pod restarts.
- `manifests/storage.yaml` — the `ollama-local` no-provisioner StorageClass
  and a static `local` PV at `/var/lib/ollama-models` on the GPU node, used by
  that PVC instead of Longhorn. See "Storage".
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

Pulled models are re-downloadable cache, so Longhorn's 3x replication (which
needs the full PVC size free on three nodes at once) and its engine overhead
buy nothing here. Ollama's PVC instead binds to a `local` PV on the GPU node
itself. Open WebUI's small PVC stays on `longhorn`, since chat history and
accounts are worth replicating.

Because the PV is static, `/var/lib/ollama-models` must already exist and be
writable on the GPU node. On Talos it must also be exposed to the kubelet,
which k8s-infra's `modules/talos-cluster/patches/ollama-models-mounts.patch.yaml`
does for GPU nodes.

To go back to Longhorn, set `persistentVolume.storageClass: longhorn` in
`ollama-values.yaml` and delete `manifests/storage.yaml`, after raising the GPU
node's `disk` in terraform-proxclus-vm-infra if needed.
