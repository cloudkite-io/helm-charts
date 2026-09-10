# monitoring

Umbrella chart around `kube-prometheus-stack`, plus `version-checker`, `x509-certificate-exporter`,
and optionally `loki` and `prometheus-blackbox-exporter`. It also ships the Grafana dashboards under
`dashboards/` and configures remote write to the central per-tenant Mimir.

## Default remote-write metrics

`kube-prometheus-stack.prometheus.prometheusSpec.remoteWrite[0].writeRelabelConfigs` is a `keep`
list: only metrics matching it are shipped to the central Mimir, everything else stays in the
cluster's own Prometheus. It is scoped to what the dashboards in `dashboards/` query, because
remote-write volume is billed.

Every family except `traefik_*` and `velero_backup*` comes from the kubelet itself or from a subchart
this chart already pulls in, so consumers do not need to install any extra exporter:

| Metric family | Source | Installed by this chart | Notes |
|---|---|---|---|
| `kubernetes_build_info` | kube-apiserver `/metrics` | yes (`kubeApiServer.enabled: true`) | |
| `version_checker_is_latest_version` | `version-checker` subchart | yes (unconditional dependency) | |
| `kube_pod_*`, `kube_node_*`, `kube_namespace_labels`, `kube_deployment_*` | kube-state-metrics | yes (`kubeStateMetrics.enabled: true`) | |
| `container_oom_events_total`, `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`, `container_network_{receive,transmit}_bytes_total` | cAdvisor, built into the kubelet | yes, scrape config only, no exporter (`kubelet.serviceMonitor.cAdvisor: true`) | `container_network_*` is dropped for CNI-owned interfaces (`cali`, `cilium`, `cni`, `lxc`, `nodelocaldns`, `tunl`); pod `eth0` is kept |
| `kubelet_volume_stats_*` | kubelet `/metrics` | yes, scrape config only, no exporter | only for PVCs currently mounted by a pod, and only if the CSI driver reports volume stats (GCE PD, EBS, Azure Disk/File all do) |
| `node_cpu_seconds_total`, `node_memory_Mem{Available,Total}_bytes`, `node_disk_*`, `node_filesystem_*` | prometheus-node-exporter | yes (subchart of kube-prometheus-stack, `nodeExporter.enabled: true`) | Linux nodes only |
| `x509_*` | `x509-certificate-exporter` subchart | yes (unconditional dependency) | |
| `traefik_service_*`, `traefik_entrypoint_*`, `traefik_config_*` | Traefik itself | **no**, see below | |
| `velero_backup*` | Velero itself | **no**, see below | |

A cluster without Traefik or Velero just sends nothing for those families: `keep` drops them
silently, with no scrape error and no remote-write cost. Their dashboard panels stay empty.

## Enabling Traefik and Velero metrics

Both are assumed to be installed already; this chart does not deploy them. Both expose Prometheus
metrics natively, so only the metrics endpoint and the ServiceMonitor need turning on in their own
release. The `release` label is what makes this chart's Prometheus select the ServiceMonitor. Use
the release name of this chart, `monitoring` in most installs.

[Traefik chart](https://github.com/traefik/traefik-helm-chart) values:

```yaml
traefik:
  metrics:
    prometheus:
      entryPoint: metrics
      service:
        enabled: true
      serviceMonitor:
        enabled: true
        interval: "30s"
        honorLabels: true
        additionalLabels:
          release: "monitoring"
```

`addEntryPointsLabels` and `addServicesLabels` default to `true`, which is what produces
`traefik_entrypoint_*` and `traefik_service_*`; no dashboard needs `traefik_router_*`
(`addRoutersLabels`, default `false`).

[Velero chart](https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero) values:

```yaml
velero:
  metrics:
    serviceMonitor:
      # Skip the CRD capability check, which silently drops the ServiceMonitor on any
      # render that cannot reach the cluster (plain `helm template`, CI diffs).
      autodetect: false
      enabled: true
      additionalLabels:
        release: "monitoring"
```

## Troubleshooting

Query the cluster's own Prometheus through the API server. `prometheus-operated` is created by the
operator, so the name is the same whatever the Helm release is called:

```bash
# Is a metric family present at all?
kubectl get --raw "/api/v1/namespaces/monitoring/services/prometheus-operated:9090\
/proxy/api/v1/query?query=count(traefik_service_requests_total)"

# Which scrape jobs are up?
kubectl get --raw "/api/v1/namespaces/monitoring/services/prometheus-operated:9090\
/proxy/api/v1/query?query=count%20by(job)(up)"
```

Or port-forward and use `curl`, which avoids URL-encoding the query:

```bash
kubectl -n monitoring port-forward svc/prometheus-operated 9090:9090 &
curl -sG http://localhost:9090/api/v1/query --data-urlencode 'query=count by(job)(up)'
```

Then:

- **A ServiceMonitor exists but its job never appears in `up`**. Check the `release` label: this
  chart sets `serviceMonitorSelectorNilUsesHelmValues: true`, so Prometheus only selects
  ServiceMonitors labelled `release: <release name of this chart>`. One created by another chart
  without that label is created successfully but never scraped, which looks exactly like the metrics
  not existing. Either add the label (as in the Traefik and Velero snippets above), or opt the
  cluster out of label filtering entirely:

  ```yaml
  kube-prometheus-stack:
    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        serviceMonitorSelector: {}
  ```

- **`node_*`, `container_*` or `kubelet_volume_stats_*` are missing**. These are cloud-agnostic, so
  check in this order: a values override setting `nodeExporter.enabled: false` or disabling the
  kubelet ServiceMonitor (more common in practice than any provider difference); GKE Autopilot or
  EKS Fargate, which block the node-exporter DaemonSet because it needs `hostNetwork`, `hostPID` and
  a host root filesystem mount; Windows nodes, which need `prometheus-windows-exporter` (off by
  default in this chart).

- **A panel is empty in the central Grafana but the metric exists in the cluster's Prometheus**. The
  metric is not in the `keep` list above. Add it there, keeping the scope tight.

- **A dashboard is missing entirely**. `dashboards.enabled` is off by default, consumers must enable
  the Grafana sidecar (`kube-prometheus-stack.grafana.sidecar.dashboards`), and the log- and
  trace-backed dashboards only ship when `dashboards.backends.logs` / `.traces` is set. See the
  `dashboards` block in `values.yaml`.
