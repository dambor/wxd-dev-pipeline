#!/bin/bash
#install minikube
echo ""
echo "=========================================================="
echo "Starting installation!"
echo "=========================================================="
echo "installing docker"
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
echo "installing kubectl"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/repodata/repomd.xml.key
EOF
yum install -y kubectl
echo "installing helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh


echo "installing kind"

# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
echo "creating kind cluster"
kind create cluster --name kind-wxd
KIND_CLUSTER_NAME="kind-wxd"
KIND_CONTAINER="^${KIND_CLUSTER_NAME}-control-plane$"

# Check if the Kind container is running
if ! docker ps --filter name="$KIND_CONTAINER" --format "{{.Names}}" | grep -q "$KIND_CLUSTER_NAME"; then

    echo "Kind cluster '$KIND_CLUSTER_NAME' is stopped or not found. Attempting to start/create..."

    # Check if the container exists at all (stopped or running)
    if docker ps -a --filter name="$KIND_CONTAINER" --format "{{.Names}}" | grep -q "$KIND_CLUSTER_NAME"; then
        # If the container exists (but is stopped), start it
        docker start "$KIND_CLUSTER_NAME-control-plane"
        echo "Kind cluster container started."
    else
        echo "Kind cluster container not found. This requires manual 'kind create cluster' or the correct cluster name."
        kind create cluster --name kind-wxd
    fi
else
    echo "Kind cluster '$KIND_CLUSTER_NAME' is running."
fi
echo "installing WXD"
helm upgrade --install wxd . -f ./values.yaml  -f ./values-secret.yaml --namespace wxd --create-namespace --timeout 120m

NAMESPACE="wxd"
# Max attempts before giving up
MAX_ATTEMPTS="120"
# Sleep between attempts (seconds)
SLEEP_TIME="20"

echo "⏳ Waiting for all pods in namespace '$NAMESPACE' to be Running/Completed..."
echo "   Max attempts: $MAX_ATTEMPTS, Sleep: ${SLEEP_TIME}s"

attempt=1
while [ $attempt -le $MAX_ATTEMPTS ]; do
    not_ready=$(kubectl get pods -n "$NAMESPACE" --no-headers \
        | grep -vE 'Running|Completed' \
        | wc -l)

    if [ "$not_ready" -eq 0 ]; then
        echo "✅ All pods are running in namespace '$NAMESPACE'."
        break
    fi

    echo "[$attempt/$MAX_ATTEMPTS] Still waiting... ($not_ready pods not ready)"
    attempt=$((attempt+1))
    sleep $SLEEP_TIME
done

kubectl get pods -n "$NAMESPACE"
nohup kubectl port-forward -n wxd  service/lhconsole-ui-svc 6443:443 --address 0.0.0.0  2>&1 &
nohup kubectl port-forward -n wxd service/ibm-lh-minio-svc 9001:9001 --address 0.0.0.0  2>&1 &
nohup kubectl port-forward -n wxd service/ibm-lh-mds-thrift-svc 8381:8381 --address 0.0.0.0  2>&1 &

# Get the hostname dynamically
HOSTNAME=$(hostname -f)

# Display completion message with dynamic hostname
echo ""
echo "=========================================================="
echo "Setup is complete!"
echo "Changes will be available at https://${HOSTNAME}:6443/#/infrastructure-manager"
echo "=========================================================="

# Made with Bob
