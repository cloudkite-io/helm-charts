# aks-karpenter-nodepools

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

Spot-first Karpenter `NodePool`s and an `AKSNodeClass` for AKS [node auto-provisioning][nap] (NAP). It also
works with self-hosted [Karpenter on Azure][provider], which uses the same CRDs.

By default it creates one `AKSNodeClass` and two NodePools:

- `spot` (weight 50): tainted, so only workloads that tolerate spot land on it.
- `on-demand` (weight 10): everything else, and the fallback when spot capacity runs out.

Both pools have a hard vCPU limit and a 4 to 16 vCPU node size range, and remove idle nodes after 5 minutes.

## Install

NAP must be enabled first. It provides the CRDs, and this chart ships none.

```bash
az aks update --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" \
  --node-provisioning-mode Auto --node-provisioning-default-pools None

helm install aks-karpenter-nodepools \
  oci://us-central1-docker.pkg.dev/cloudkite-public/public-helm-charts/aks-karpenter-nodepools \
  --version 0.1.0 --values my-values.yaml
```

## Running workloads on spot

A workload opts in with a toleration. Nothing lands on spot without one:

```yaml
tolerations:
  - key: kubernetes.azure.com/scalesetpriority
    operator: Equal
    value: spot
    effect: NoSchedule
```

To favor spot over on-demand, also add a preferred node affinity for
`kubernetes.azure.com/scalesetpriority In [spot]`. CloudKite's [`standard-app`][standard-app] chart renders
both with `preferSpot: aks`. Karpenter sets that label itself (`spot` or `regular`), so selectors written for
fixed AKS spot pools keep working. Don't set it in `labels`.

## Things to know

- **AKS's own `default` NodePool has no limits.** With `--node-provisioning-default-pools Auto`, Karpenter
  falls back to it once your pools reach `limits.cpu`, so your limits stop capping capacity. Use `None`
  (your system node pool then needs headroom for system add-ons), or set limits on AKS's pool. AKS also
  owns an `AKSNodeClass` called `default`, so don't give `nodeClass.name` that name.
- **Spot price can't be capped.** NAP bids up to the on-demand price, so `limits.cpu` and `maxSkuCpu` are
  your cost controls.
- **Some changes replace nodes.** Karpenter treats a change to `nodeClass`, or to a pool's `labels` or
  `taints`, as drift, and replaces those nodes within disruption budgets and PodDisruptionBudgets.
- **Uninstalling deletes the nodes.** Deleting a NodePool drains and removes every node provisioned from
  it. Move workloads off first.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| nodeClass.name | string | `"general-purpose"` | Name of the AKSNodeClass. Avoid `default` on clusters that keep AKS's default NodePools: AKS already owns an AKSNodeClass by that name. |
| nodeClass.description | string | `"General purpose AKSNodeClass for application workloads"` | Written to the `kubernetes.io/description` annotation. Set to `""` to omit. |
| nodeClass.imageFamily | string | `"Ubuntu"` | Node OS image family: `Ubuntu` (version follows the cluster's Kubernetes version), `Ubuntu2204`, `Ubuntu2404` or `AzureLinux`. |
| nodeClass.osDiskSizeGB | int | `128` | OS disk size in GB (minimum 30). NAP uses an ephemeral OS disk when the chosen VM size has room for one this big, otherwise a managed disk. |
| nodeClass.maxPods | int | AKS default for the cluster's network plugin (250 on Azure CNI Overlay, 30 on Azure CNI node subnet) | Maximum pods per node (10-250). |
| nodeClass.tags | object | `{"managed-by":"karpenter"}` | Azure resource tags applied to every VM provisioned through this node class. |
| nodePools | object | a tainted `spot` pool and an `on-demand` fallback pool; see the rows below | NodePools to create, keyed by NodePool name. Every entry accepts the fields shown on `nodePools.spot`. Pools you add do not inherit anything from the defaults below: they need at least `capacityType` and `limits.cpu`. Remove a default pool by setting it to `null` (for example `nodePools.spot: null`). |
| nodePools.spot.weight | int | `50` | Priority when a pod fits more than one NodePool (1-100; higher wins). |
| nodePools.spot.capacityType | list | `["spot"]` | Values for `karpenter.sh/capacity-type`: `spot`, `on-demand`, or both. |
| nodePools.spot.arch | list | `["amd64"]` | Values for `kubernetes.io/arch`: `amd64`, `arm64`, or both. |
| nodePools.spot.skuFamily | list | `["D","F"]` | VM size families allowed (`karpenter.azure.com/sku-family`), e.g. `D` general purpose, `F` compute optimized, `E` memory optimized. Empty allows every family. |
| nodePools.spot.zones | list | `[]` | Availability zones allowed, as `<region>-<n>` (e.g. `eastus-1`). Empty allows every zone in the cluster's region. Pin this on single-zone clusters. |
| nodePools.spot.minSkuCpu | string | `"3"` | Node size floor: vCPU count must be greater than this. `"3"` means 4 vCPU or more, which keeps the per-node DaemonSet overhead to a small share of each node. |
| nodePools.spot.maxSkuCpu | string | `"17"` | Node size cap: vCPU count must be less than this. `"17"` means 16 vCPU or fewer, so one spot eviction can't take out a large slice of the cluster. |
| nodePools.spot.labels | object | `{}` | Extra labels on every node in this pool (`provisioned-by: karpenter` is always added). Never set `kubernetes.azure.com/scalesetpriority`: the Azure provider writes it. |
| nodePools.spot.taints | list | `[{"effect":"NoSchedule","key":"kubernetes.azure.com/scalesetpriority","value":"spot"}]` | Taints on every node in this pool. The default keeps workloads off spot unless they tolerate it. |
| nodePools.spot.expireAfter | string | `"Never"` | Maximum node lifetime. `Never` leaves node replacement to NAP's image upgrades and to consolidation. |
| nodePools.spot.extraRequirements | list | `[]` | Extra NodePool requirements, appended to the ones above. Use for any `karpenter.azure.com/*` selector the chart has no field for (sku-name, sku-gpu-manufacturer, sku-storage-premium-capable, ...). |
| nodePools.spot.limits.cpu | string | `"96"` | Required. Total vCPU this pool may provision across all its nodes. Add `limits.memory` (e.g. `256Gi`) for a memory ceiling as well. |
| nodePools.spot.disruption.consolidationPolicy | string | `"WhenEmptyOrUnderutilized"` | `WhenEmptyOrUnderutilized` also repacks pods off under-used nodes; `WhenEmpty` only removes nodes with nothing left on them. |
| nodePools.spot.disruption.consolidateAfter | string | `"5m"` | How long a node must be empty or under-used before Karpenter acts on it. |
| nodePools.spot.disruption.budgets | list | `[]` (Karpenter's default of 10% of nodes at a time) | Rate limits on voluntary node replacement, e.g. `[{nodes: "20%"}, {nodes: "0", schedule: "0 9 * * mon-fri", duration: 8h}]`. |
| nodePools.on-demand | object | as `spot` but on-demand, weight 10, no taint, `kubernetes/nodetype: regular` label, 32 vCPU limit | Catches every workload that hasn't opted into spot, and spot-tolerant workloads when spot capacity is unavailable. Same fields as `nodePools.spot`. `kubernetes/nodetype: regular` is the label CloudKite's `standard-app` chart prefers for non-spot capacity; keep it if any workload pins it with required node affinity. |

## Development

`README.md` is generated by [helm-docs](https://github.com/norwoodj/helm-docs). Edit `README.md.gotmpl` or
the `# --` comments in `values.yaml`, then run this from the repository root

```bash
helm-docs --chart-search-root aks-karpenter-nodepools --sort-values-order file
```

Merging to `main` publishes the `version` in `Chart.yaml`. The workflow won't overwrite a published version,
so bump it with every change.

[nap]: https://learn.microsoft.com/azure/aks/node-auto-provisioning
[provider]: https://github.com/Azure/karpenter-provider-azure
[standard-app]: https://github.com/cloudkite-io/helm-standard-library
