# Vertical Pod Autoscaler Helm Chart

This Helm chart simplifies the deployment of the Vertical Pod Autoscaler (VPA) in a Kubernetes cluster. It templates the manifests from the official [Vertical Pod Autoscaler repository](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler/deploy) and adds flexibility for custom configurations.

This chart integrates with **Cert-Manager** to manage issuers and certificates.

---

## Prerequisites

Before deploying this chart, ensure the following prerequisites are met:

- **[Cert-Manager](https://cert-manager.io/)**: Cert-Manager is required to manage the certificate and issuer for VPA components. Ensure Cert-Manager is installed and configured in your Kubernetes cluster before deploying this chart.
