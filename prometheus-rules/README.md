# Prometheus Rule Helm Chart

This Helm chart installs Promrtheus Rules, which integrates with either `kube-prometheus-stack` or stand alone prometheus installation.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)

## Prerequisites

Before you begin, ensure you have the following prerequisites in place:

- **Helm**: Make sure you have Helm installed on your local machine and it's configured to work with your Kubernetes cluster. If not, you can follow the [official Helm installation guide](https://helm.sh/docs/intro/install/).

## Installation

### Local
To install this Helm chart, follow these steps:

1. Clone the repository to your local machine:

    ```sh
    git clone https://github.com/cloudkite-io/helm-charts
    ```

2. Change into the chart directory:

    ```sh
    cd helm-charts/prometheus-rules
    ```
   Modify the `values.yaml` to enable the list of rules you want.

3. Install the Helm chart with a release name (e.g., `cloudkitepromrules`):

    ```sh
    helm install cloudkitepromrules .
    ```

### Helm Templating
1. Create a values.yaml file to customise your values.

    ```values.yaml
    nginx_ingress:
      enabled: false
    velero:
      enabled: true
    solr:
      enabled: false
    kubernetes:
      enabled: true

    ```

Charts.yaml file:

    ```Charts.yaml
    apiVersion: v2
    description: Cloudkite prometheus-rules chart
    name: prometheus-rules
    version: 0.1.0
    dependencies:
    - name: prometheus-rules
        version: 0.1.0
        repository: oci://us-central1-docker.pkg.dev/cloudkite-public/public-helm-charts
    ```

2. Install or upgrade the Helm chart.
