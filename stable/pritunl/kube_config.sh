set -xe

PROXY_PORT=8080
NODE_NAME=$(kubectl get node -o name | head -n 1 | sed 's/node\///g')
CONFIGMAP_NAME=node-config

kubectl proxy --port $PROXY_PORT &

curl -sSL "http://localhost:${PROXY_PORT}/api/v1/nodes/${NODE_NAME}/proxy/configz" \
        | jq '.kubeletconfig|.kind="KubeletConfiguration"|.apiVersion="kubelet.config.k8s.io/v1beta1"' \
        > kubelet_configz_${NODE_NAME}

kubectl -n kube-system create configmap ${CONFIGMAP_NAME} --from-file=kubelet=kubelet_configz_${NODE_NAME} -o yaml

kubectl patch node ${NODE_NAME} -p "{\"spec\":{\"configSource\":{\"configMap\":{\"name\":\"${CONFIGMAP_NAME}\",\"namespace\":\"kube-system\",\"kubeletConfigKey\":\"kubelet\"}}}}"
