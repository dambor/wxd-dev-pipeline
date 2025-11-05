#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    printf "%b\n" "${BLUE}ℹ${NC} $1"
}

log_success() {
    printf "%b\n" "${GREEN}✓${NC} $1"
}

log_warn() {
    printf "%b\n" "${YELLOW}⚠${NC} $1"
}

log_error() {
    printf "%b\n" "${RED}✗${NC} $1"
}

# Check if running on macOS
check_os() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only. Detected OS: $OSTYPE"
        exit 1
    fi
    log_success "Running on macOS"
}

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_warn "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew installed"
    else
        log_success "Homebrew is installed"
    fi
}

# Check and install kubectl
check_kubectl() {
    if command -v kubectl &> /dev/null; then
        local version=$(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "kubectl is installed (version: $version)"
    else
        log_warn "kubectl not found. Installing..."
        brew install kubectl
        log_success "kubectl installed"
    fi
}

# Check and install Helm
check_helm() {
    if command -v helm &> /dev/null; then
        local version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "Helm is installed (version: $version)"
    else
        log_warn "Helm not found. Installing..."
        brew install helm
        log_success "Helm installed"
    fi
}

# Check and install OpenShift CLI (oc)
check_oc() {
    if command -v oc &> /dev/null; then
        local version=$(oc version --client -o json 2>/dev/null | grep -oE '"releaseVersion":"[^"]*' | cut -d'"' -f4 || echo "unknown")
        log_success "OpenShift CLI (oc) is installed (version: $version)"
    else
        log_warn "OpenShift CLI (oc) not found. Installing..."
        brew install openshift-cli
        log_success "OpenShift CLI (oc) installed"
    fi
}

# Verify all tools are installed and accessible
verify_installations() {
    log_info "Verifying all tools are accessible..."
    
    local all_ok=true
    
    for tool in kubectl helm oc; do
        if command -v $tool &> /dev/null; then
            log_success "$tool verified"
        else
            log_error "$tool verification failed"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = false ]; then
        log_error "Some tools failed verification"
        exit 1
    fi
    
    log_success "All tools verified successfully!"
}

# Prompt for oc login
prompt_oc_login() {
    if oc whoami &> /dev/null; then
        local user=$(oc whoami)
        local cluster=$(oc cluster-info | grep 'Kubernetes master' | awk -F'//' '{print $2}' | awk -F':' '{print $1}' || oc config current-context)
        log_success "Already authenticated to OpenShift"
        log_success "Logged in as: $user"
        log_success "Cluster: $cluster"
        return 0
    fi
    
    log_info "OpenShift cluster authentication required"
    echo ""
    printf "%b\n" "${YELLOW}Please paste your OpenShift login command:${NC}"
    printf "%b\n" "${BLUE}Example: oc login --token=sha256~XXX --server=https://api.xxx.com:6443${NC}"
    echo ""
    
    read -p "Paste oc login command: " oc_login_cmd
    
    if [ -z "$oc_login_cmd" ]; then
        log_error "No login command provided"
        exit 1
    fi
    
    log_info "Executing login command..."
    eval "$oc_login_cmd"
    
    if [ $? -eq 0 ]; then
        log_success "Successfully authenticated to OpenShift cluster"
        local user=$(oc whoami 2>/dev/null)
        log_success "Logged in as: $user"
    else
        log_error "Failed to authenticate to OpenShift cluster"
        exit 1
    fi
    echo ""
}

# Setup OpenShift environment
setup_openshift_env() {
    log_info "Setting up OpenShift environment..."
    
    log_info "Adding Bitnami Helm repository..."
    read -p "Do you want to add the Bitnami Helm repository? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm repo add bitnami https://charts.bitnami.com/bitnami || log_warn "Bitnami repo may already exist"
        helm repo update
        log_success "Helm repositories updated"
    else
        log_warn "Skipping Bitnami Helm repository"
    fi
    echo ""
    
    log_info "Creating 'wxd' namespace..."
    kubectl create namespace wxd 2>/dev/null || log_warn "Namespace 'wxd' may already exist"
    log_success "Namespace ready"
    
    log_info "Patching default service account..."
    kubectl patch serviceaccount default -n wxd \
        -p '{"imagePullSecrets": [{"name": "docker-pull-secret"}, {"name": "icr-pull"}]}' \
        2>/dev/null || log_warn "Service account patch may have skipped (secrets might not exist yet)"
    log_success "Service account patched"
}

# Deploy Helm chart
deploy_helm_chart() {
    log_info "Deploying Helm chart..."
    
    if [ ! -f "./values.yaml" ]; then
        log_error "values.yaml not found in current directory"
        exit 1
    fi
    
    if [ ! -f "./values-secret.yaml" ]; then
        log_warn "values-secret.yaml not found. Proceeding without it."
        SECRETS_FILE=""
    else
        SECRETS_FILE="-f ./values-secret.yaml"
    fi
    
    log_info "Starting Helm upgrade/install..."
    helm upgrade --install wxd . \
        --namespace wxd \
        --create-namespace \
        --timeout 120m \
        -f ./values.yaml \
        $SECRETS_FILE \
        --set securityContext.enableOpenShiftSettings=true \
        --set pvc.storageClassName=ocs-external-storagecluster-ceph-rbd \
        --set global.postgresql.primary.persistence.storageClass=ocs-external-storagecluster-ceph-rbd
    
    log_success "Helm chart deployed"
}

# Monitor installation
monitor_installation() {
    log_info "Monitoring installation status..."
    log_info "Waiting for pods to be ready (Press Ctrl+C to stop watching)..."
    
    while [ $(kubectl get pods -n wxd 2>/dev/null | wc -l) -lt 2 ]; do
        sleep 2
    done
    
    timeout 120 kubectl get pods -n wxd --watch || true
    
    log_info "Pod monitoring ended. Checking final status..."
    kubectl get pods -n wxd
}

# Apply startup fix for spark-hb-control-plane
apply_startup_fix() {
    log_info "Applying startup fix for spark-hb-control-plane..."
    
    if ! kubectl get deployment spark-hb-control-plane -n wxd &> /dev/null; then
        log_warn "spark-hb-control-plane deployment not found. Skipping startup fix."
        return 0
    fi
    
    log_info "Creating startup-fix.sh..."
    cat > startup-fix.sh << 'STARTUPEOF'
#!/bin/bash
mkdir -p /tmp/postgres_certs
if [ -d "/opt/hb/confidential_config/postgres_certs" ] && [ "$(ls -A /opt/hb/confidential_config/postgres_certs 2>/dev/null)" ]; then
    cp /opt/hb/confidential_config/postgres_certs/* /tmp/postgres_certs/ 2>/dev/null || true
else
    echo "PostgreSQL certificates not found or SSL disabled - skipping cert copy"
fi
if [ ! -d "/logs" ]; then
    echo "Warning: /logs directory not found"
fi
STARTUPEOF
    
    log_info "Creating ConfigMap..."
    kubectl delete configmap startup-fix -n wxd 2>/dev/null || true
    sleep 1
    kubectl create configmap startup-fix --from-file=startup.sh=startup-fix.sh -n wxd
    log_success "ConfigMap created"
    
    log_info "Patching spark-hb-control-plane deployment..."
    kubectl patch deployment spark-hb-control-plane -n wxd --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {
      "name": "startup-fix",
      "configMap": {
        "name": "startup-fix",
        "defaultMode": 493
      }
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-",
    "value": {
      "name": "startup-fix",
      "mountPath": "/startup.sh",
      "subPath": "startup.sh"
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers",
    "value": [
      {
        "name": "fix-logs-permissions",
        "image": "busybox:1.35",
        "command": ["sh", "-c", "chown -R 1001:1001 /logs && chmod -R 755 /logs"],
        "volumeMounts": [
          {
            "name": "control-plane-logs",
            "mountPath": "/logs",
            "subPath": "control-plane-logs"
          }
        ],
        "securityContext": {
          "runAsUser": 0
        }
      }
    ]
  }
]' 2>/dev/null
    
    log_success "Deployment patched"
    
    log_info "Waiting for pod to restart..."
    sleep 5
    kubectl get pods -n wxd -l app=spark-hb-control-plane --watch &
    local watch_pid=$!
    
    local counter=0
    while [ $counter -lt 24 ]; do
        local pod_status=$(kubectl get pod -l app=spark-hb-control-plane -n wxd -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        local ready_status=$(kubectl get pod -l app=spark-hb-control-plane -n wxd -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        
        if [ "$pod_status" = "Running" ] && [ "$ready_status" = "True" ]; then
            kill $watch_pid 2>/dev/null || true
            break
        fi
        sleep 5
        ((counter++))
    done
    
    kill $watch_pid 2>/dev/null || true
    
    log_success "Pod restarted"
    
    log_info "Verifying the fix..."
    sleep 2
    kubectl get pod -l app=spark-hb-control-plane -n wxd
    
    log_info "Checking pod logs..."
    kubectl logs -l app=spark-hb-control-plane -n wxd -c spark-hb-control-plane 2>/dev/null | head -5 || log_warn "Could not retrieve logs yet"
    
    log_info "Cleaning up..."
    rm -f startup-fix.sh
    
    log_success "Startup fix applied successfully!"
}

# Apply Presto permission fix
apply_presto_fix() {
    log_info "Applying permission fix for Presto..."
    
    if ! kubectl get deployment ibm-lh-presto -n wxd &> /dev/null; then
        log_warn "ibm-lh-presto deployment not found. Skipping Presto fix."
        return 0
    fi
    
    log_info "Adding init container to fix PVC ownership..."
    kubectl patch deployment ibm-lh-presto -n wxd --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/initContainers/0", "value": {
    "name": "fix-permissions",
    "image": "busybox",
    "command": ["sh", "-c", "chown -R 1001:1001 /catalog && chmod -R 755 /catalog"],
    "volumeMounts": [{"name": "catalog-vol", "mountPath": "/catalog"}],
    "securityContext": {"runAsUser": 0}
  }}
]' 2>/dev/null
    
    log_success "Init container added"
    
    log_info "Adding resource limits..."
    kubectl patch deployment ibm-lh-presto -n wxd --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "3Gi", "cpu": "1"}, "limits": {"memory": "4Gi", "cpu": "2"}}}
]' 2>/dev/null || log_warn "Could not add resource limits"
    
    log_success "Resource limits added"
    
    log_info "Waiting for Presto pod to restart..."
    sleep 5
    
    kubectl rollout status deployment/ibm-lh-presto -n wxd --timeout=5m
    
    if [ $? -eq 0 ]; then
        log_success "Presto pod restarted successfully"
        
        log_info "Verifying Presto deployment..."
        kubectl get pod -l app=ibm-lh-presto -n wxd
        
        log_success "Presto permission fix applied successfully!"
    else
        log_warn "Presto pod restart timed out, but fix may still be applied"
    fi
}

# Create OpenShift Routes
create_openshift_routes() {
    log_info "Creating OpenShift Routes for external access..."
    
    # Check if routes exist
    local routes_exist=false
    if oc get route lhconsole-ui -n wxd &> /dev/null || oc get route minio-ui -n wxd &> /dev/null || oc get route mds-thrift -n wxd &> /dev/null; then
        routes_exist=true
    fi
    
    if [ "$routes_exist" = true ]; then
        log_warn "Some routes already exist"
        read -p "Do you want to recreate the routes? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warn "Skipping route creation"
            return 0
        fi
    fi
    
    log_info "Creating route for lhconsole-ui-svc..."
    oc delete route lhconsole-ui -n wxd 2>/dev/null || true
    sleep 1
    oc create route passthrough lhconsole-ui \
        -n wxd \
        --service=lhconsole-ui-svc \
        --port=8443 \
        2>/dev/null || log_warn "Route 'lhconsole-ui' creation failed"
    
    log_info "Creating route for MinIO..."
    oc delete route minio-ui -n wxd 2>/dev/null || true
    sleep 1
    oc create route edge minio-ui \
        -n wxd \
        --service=ibm-lh-minio-svc \
        --port=9001 \
        --insecure-policy=Redirect \
        2>/dev/null || log_warn "Route 'minio-ui' creation failed"
    
    log_info "Creating route for MDS Thrift..."
    oc delete route mds-thrift -n wxd 2>/dev/null || true
    sleep 1
    oc create route passthrough mds-thrift \
        -n wxd \
        --service=ibm-lh-mds-thrift-svc \
        --port=8381 \
        2>/dev/null || log_warn "Route 'mds-thrift' creation failed"
    
    log_success "OpenShift Routes created"
}

# Display access information
display_access_info() {
    log_info "Retrieving OpenShift Route information..."
    
    sleep 2
    
    local ui_route=$(oc get route lhconsole-ui -n wxd -o jsonpath='{.spec.host}' 2>/dev/null)
    local minio_route=$(oc get route minio-ui -n wxd -o jsonpath='{.spec.host}' 2>/dev/null)
    local mds_route=$(oc get route mds-thrift -n wxd -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -n "$ui_route" ] || [ -n "$minio_route" ] || [ -n "$mds_route" ]; then
        echo ""
        printf "%b\n" "${GREEN}═══════════════════════════════════════════════════════${NC}"
        printf "%b\n" "${GREEN}       OpenShift Routes - Access Information${NC}"
        printf "%b\n" "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
        
        if [ -n "$ui_route" ]; then
            log_success "Main Console UI Route:"
            printf "%b\n" "${YELLOW}https://${ui_route}/#/infrastructure-manager${NC}"
            echo ""
        fi
        
        if [ -n "$minio_route" ]; then
            log_success "MinIO UI Route:"
            printf "%b\n" "${YELLOW}https://${minio_route}${NC}"
            echo ""
        fi
        
        if [ -n "$mds_route" ]; then
            log_success "MDS Thrift Route:"
            printf "%b\n" "${YELLOW}${mds_route}:8381${NC}"
            echo ""
        fi
        
        printf "%b\n" "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo ""
    else
        log_error "Could not retrieve route hostnames"
    fi
}

# Setup CQL Proxy on OpenShift
setup_cql_proxy() {
    log_info "Setting up CQL Proxy on OpenShift..."
    echo ""
    
    log_info "Please provide your Astra DB credentials:"
    echo ""
    
    read -p "Enter your Astra Token (AstraCS:...): " astra_token
    
    if [ -z "$astra_token" ]; then
        log_error "Astra Token cannot be empty"
        return 1
    fi
    
    echo ""
    read -p "Enter your Astra Database ID (UUID): " astra_db_id
    
    if [ -z "$astra_db_id" ]; then
        log_error "Astra Database ID cannot be empty"
        return 1
    fi
    
    echo ""
    log_info "Creating CQL Proxy deployment on OpenShift..."
    
    cat > cql-proxy-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cql-proxy
  namespace: wxd
  labels:
    app: cql-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cql-proxy
  template:
    metadata:
      labels:
        app: cql-proxy
    spec:
      containers:
      - name: cql-proxy
        image: datastax/cql-proxy:v0.2.0
        args:
        - --astra-token
        - $astra_token
        - --astra-database-id
        - $astra_db_id
        ports:
        - containerPort: 9042
          protocol: TCP
EOF
    
    kubectl delete deployment cql-proxy -n wxd 2>/dev/null || true
    sleep 1
    kubectl apply -f cql-proxy-deployment.yaml
    rm -f cql-proxy-deployment.yaml
    log_success "CQL Proxy deployment created"
    
    echo ""
    log_info "Creating NodePort service for CQL Proxy..."
    
    cat > cql-proxy-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: cql-proxy-nodeport
  namespace: wxd
  labels:
    app: cql-proxy
spec:
  type: NodePort
  ports:
  - port: 9042
    targetPort: 9042
    protocol: TCP
  selector:
    app: cql-proxy
EOF
    
    kubectl delete service cql-proxy-nodeport -n wxd 2>/dev/null || true
    sleep 1
    kubectl apply -f cql-proxy-nodeport.yaml
    rm -f cql-proxy-nodeport.yaml
    log_success "CQL Proxy NodePort service created"
    
    echo ""
    log_info "Waiting for CQL Proxy pod to be ready..."
    kubectl rollout status deployment/cql-proxy -n wxd --timeout=5m
    
    if [ $? -eq 0 ]; then
        sleep 2
        local node_port=$(kubectl get service cql-proxy-nodeport -n wxd -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
        local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
        
        if [ -z "$node_ip" ]; then
            node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
        fi
        
        log_success "CQL Proxy is running"
        echo ""
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║       CQL Proxy - Connection Information              ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        log_success "CQL Proxy NodePort Service:"
        printf "%b\n" "${YELLOW}Node IP: ${node_ip}${NC}"
        printf "%b\n" "${YELLOW}NodePort: ${node_port}${NC}"
        echo ""
        printf "%b\n" "${BLUE}Connection String:${NC}"
        printf "%b\n" "${YELLOW}${node_ip}:${node_port}${NC}"
        echo ""
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        log_info "You can now connect to your Astra DB via the CQL Proxy using the NodePort"
    else
        log_error "Failed to deploy CQL Proxy or pods failed to start"
        return 1
    fi
}

# Main execution
main() {
    clear
    
    printf "%b\n" "${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   OpenShift & IBM Lakehouse Setup & Deployment        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "%b\n" "${NC}"
    
    log_info "Phase 0: OpenShift Authentication..."
    prompt_oc_login
    
    log_info "Phase 1: Verifying OS and Homebrew..."
    check_os
    check_homebrew
    echo ""
    
    log_info "Phase 2: Checking and installing required tools..."
    check_kubectl
    check_helm
    check_oc
    echo ""
    
    log_info "Phase 3: Verifying installations..."
    verify_installations
    echo ""
    
    log_info "Phase 4: Setting up OpenShift environment..."
    setup_openshift_env
    echo ""
    
    log_info "Phase 5: Deploying Helm chart..."
    read -p "Do you want to deploy the Helm chart? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_helm_chart
    else
        log_warn "Skipping Helm chart deployment"
    fi
    echo ""
    
    log_info "Phase 6: Monitoring installation..."
    read -p "Do you want to monitor the installation? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        monitor_installation
    else
        log_warn "Skipping installation monitoring"
    fi
    echo ""
    
    log_info "Phase 7: Applying startup fix..."
    read -p "Do you want to apply the startup fix? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_startup_fix
    else
        log_warn "Skipping startup fix"
    fi
    echo ""
    
    log_info "Phase 8: Applying Presto permission fix..."
    read -p "Do you want to apply the Presto permission fix? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_presto_fix
    else
        log_warn "Skipping Presto permission fix"
    fi
    echo ""
    
    log_info "Phase 9: Creating OpenShift Routes..."
    create_openshift_routes
    echo ""
    
    log_info "Phase 10: Displaying access information..."
    display_access_info
    
    log_success "Setup and deployment completed successfully!"
    echo ""
    
    read -p "Do you want to set up CQL Proxy for Astra DB? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        setup_cql_proxy
    else
        log_warn "Skipping CQL Proxy setup"
    fi
    
    echo ""
    log_success "All done! 🎉"
}

main "$@"