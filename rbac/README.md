# RBAC Helm Chart

This Helm chart is designed to simplify the management of AWS authentication and RBAC (Role-Based Access Control) resources on an Amazon EKS (Elastic Kubernetes Service) cluster. It contains resources that allows you to easily override the `aws-auth` ConfigMap and map new roles to users in your Kubernetes cluster. It can also be used to create cluster roles and cluster role bindings.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)

## Prerequisites

Before you begin, ensure you have the following prerequisites in place:

- **Helm**: Make sure you have Helm installed on your local machine and it's configured to work with your Kubernetes cluster. If not, you can follow the [official Helm installation guide](https://helm.sh/docs/intro/install/).

- **kubectl**: You should have `kubectl` configured to work with your EKS cluster. Follow the [AWS EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html) for instructions on configuring `kubectl` for EKS.

## Installation

### Local
To install this Helm chart, follow these steps:

1. Clone the repository to your local machine:

    ```sh
    git clone https://github.com/cloudkite-io/helm-charts
    ```

2. Change into the chart directory:

    ```sh
    cd helm-charts/rbac
    ```
   Modify the `values.yaml` file with your custom values.

3. Install the Helm chart with a release name (e.g., `aws-auth`):

    ```sh
    helm install aws-auth .
    ```

   Replace `aws-auth` with the desired release name and modify the chart values as needed.

### Helm Templating
Create a values.yaml file to customise your values.

    ```values.yaml
    awsauth:
    enable: true
    configmapdata:
        - name: mapRoles
        value: |
            - groups:
            - system:bootstrappers
            - system:nodes
            rolearn: <role-arn>
            username: system:node:{{EC2PrivateDNSName}}
    ```

Charts.yaml file:

    ```Charts.yaml
    apiVersion: v2
    description: Cloudkite rbac chart
    name: rbac
    version: 0.1.0
    dependencies:
    - name: rbac
        version: 0.1.0
        repository: oci://us-central1-docker.pkg.dev/cloudkite-public/public-helm-charts
    ```

## Usage

### Overriding the `aws-auth` ConfigMap

To override the `aws-auth` ConfigMap, follow these steps:

1. Edit the `values.yaml` file to define the desired configuration for your `aws-auth` ConfigMap under the `configMapOverrides` section.

2. Manually delete the existing a`aws-auth` configmap if there is any.

    ```sh
    kubectl get configmap aws-auth -n kube-system
    ```

3. Install or upgrade the Helm chart as described in the [Installation](#installation) section.

### Mapping AWS IAM Roles to Kubernetes Users

To map AWS IAM roles to Kubernetes users, follow these steps:

1. Edit the `values.yaml` file to define the mapping rules under the `mapRoles` section.

    ```yaml
    mapRoles:
      - rolearn: arn:aws:iam::123456789012:role/my-eks-role
        username: my-eks-user
        groups:
          - system:masters
      # Add more role mappings as needed
    ```

2. Install or upgrade the Helm chart as described in the [Installation](#installation) section.