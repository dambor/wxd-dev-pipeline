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

# Confirm action
confirm() {
    local prompt="$1"
    local response
    read -p "$(printf "%b" "${YELLOW}${prompt}${NC}")" -n 1 -r
    echo
    [[ $RESPONSE =~ ^[Yy]$ ]]
}

# Check if oc is available
check_oc_connection() {
    if ! oc whoami &> /dev/null; then
        log_error "Not authenticated to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    
    local user=$(oc whoami)
    local cluster=$(oc config current-context)
    log_success "Connected to cluster as: $user"
    log_success "Cluster context: $cluster"
}

# Delete Helm release
delete_helm_release() {
    log_info "Checking Helm release status..."
    
    if helm list -n wxd | grep -q wxd; then
        log_warn "Helm release 'wxd' found in namespace 'wxd'"
        read -p "$(printf "%b" "${YELLOW}Delete Helm release? (y/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting Helm release 'wxd'..."
            helm uninstall wxd -n wxd
            log_success "Helm release deleted"
        else
            log_warn "Skipping Helm release deletion"
        fi
    else
        log_warn "Helm release 'wxd' not found"
    fi
}

# Delete OpenShift Routes
delete_routes() {
    log_info "Checking for OpenShift routes..."
    
    local routes_to_delete=("lhconsole-ui" "minio-ui" "mds-thrift" "cql-proxy")
    local found_routes=false
    
    for route in "${routes_to_delete[@]}"; do
        if oc get route "$route" -n wxd &> /dev/null; then
            found_routes=true
            log_warn "Route '$route' found"
        fi
    done
    
    if [ "$found_routes" = true ]; then
        read -p "$(printf "%b" "${YELLOW}Delete all OpenShift routes? (y/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting routes..."
            for route in "${routes_to_delete[@]}"; do
                oc delete route "$route" -n wxd 2>/dev/null && log_success "Deleted route: $route" || log_warn "Route $route not found"
            done
        else
            log_warn "Skipping route deletion"
        fi
    else
        log_warn "No routes found"
    fi
}

# Delete ConfigMaps
delete_configmaps() {
    log_info "Checking for ConfigMaps..."
    
    local configmaps_to_delete=("startup-fix")
    local found_configmaps=false
    
    for cm in "${configmaps_to_delete[@]}"; do
        if kubectl get configmap "$cm" -n wxd &> /dev/null; then
            found_configmaps=true
            log_warn "ConfigMap '$cm' found"
        fi
    done
    
    if [ "$found_configmaps" = true ]; then
        read -p "$(printf "%b" "${YELLOW}Delete startup-fix ConfigMap? (y/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting ConfigMaps..."
            for cm in "${configmaps_to_delete[@]}"; do
                kubectl delete configmap "$cm" -n wxd 2>/dev/null && log_success "Deleted ConfigMap: $cm" || log_warn "ConfigMap $cm not found"
            done
        else
            log_warn "Skipping ConfigMap deletion"
        fi
    else
        log_warn "No ConfigMaps found"
    fi
}

# Delete CQL Proxy
delete_cql_proxy() {
    log_info "Checking for CQL Proxy deployment..."
    
    if kubectl get deployment cql-proxy -n wxd &> /dev/null; then
        log_warn "CQL Proxy deployment found"
        read -p "$(printf "%b" "${YELLOW}Delete CQL Proxy deployment and service? (y/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting CQL Proxy deployment..."
            kubectl delete deployment cql-proxy -n wxd 2>/dev/null && log_success "Deleted CQL Proxy deployment" || true
            
            log_info "Deleting CQL Proxy services..."
            kubectl delete service cql-proxy-svc -n wxd 2>/dev/null && log_success "Deleted CQL Proxy ClusterIP service" || true
            kubectl delete service cql-proxy-nodeport -n wxd 2>/dev/null && log_success "Deleted CQL Proxy NodePort service" || true
        else
            log_warn "Skipping CQL Proxy deletion"
        fi
    else
        log_warn "CQL Proxy deployment not found"
    fi
}

# Delete namespace
delete_namespace() {
    log_info "Checking for 'wxd' namespace..."
    
    if kubectl get namespace wxd &> /dev/null; then
        log_warn "Namespace 'wxd' found"
        read -p "$(printf "%b" "${RED}⚠ DELETE ENTIRE NAMESPACE? This will remove all resources! (y/n): ${NC}")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deleting namespace 'wxd' and all resources..."
            kubectl delete namespace wxd --wait=true
            log_success "Namespace 'wxd' deleted"
        else
            log_warn "Skipping namespace deletion"
        fi
    else
        log_warn "Namespace 'wxd' not found"
    fi
}

# Verify deletion
verify_deletion() {
    log_info "Verifying cleanup..."
    
    if kubectl get namespace wxd &> /dev/null; then
        log_error "Namespace 'wxd' still exists"
        return 1
    else
        log_success "Namespace 'wxd' successfully removed"
    fi
    
    return 0
}

# Show remaining resources
show_remaining_resources() {
    log_info "Checking for remaining resources in other namespaces..."
    
    local remaining=$(kubectl get all -A --field-selector metadata.namespace!=default,metadata.namespace!=kube-system,metadata.namespace!=kube-public,metadata.namespace!=kube-node-lease,metadata.namespace!=openshift-console,metadata.namespace!=openshift-system 2>/dev/null | wc -l)
    
    if [ "$remaining" -gt 1 ]; then
        log_warn "Found other resources in the cluster that may be related"
        log_info "Run 'kubectl get all -A' to see all resources"
    else
        log_success "No other namespaces with resources found"
    fi
}

# Main uninstall
main() {
    clear
    
    printf "%b\n" "${RED}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  OpenShift & IBM Lakehouse - Uninstall Script         ║"
    echo "╚════════════════════════════════════════════════════════╝"
    printf "%b\n" "${NC}"
    
    echo ""
    log_warn "This script will remove IBM Lakehouse deployment from your OpenShift cluster"
    echo ""
    
    # Verify cluster connection
    log_info "Phase 0: Verifying cluster connection..."
    check_oc_connection
    echo ""
    
    # Confirm uninstall
    log_warn "You are about to uninstall IBM Lakehouse from namespace 'wxd'"
    read -p "$(printf "%b" "${RED}Are you sure you want to proceed? (y/n): ${NC}")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Uninstall cancelled"
        exit 0
    fi
    
    echo ""
    log_error "Starting uninstall process..."
    echo ""
    
    # Phase 1: Delete Helm release
    log_info "Phase 1: Deleting Helm release..."
    delete_helm_release
    echo ""
    
    # Phase 2: Delete routes
    log_info "Phase 2: Deleting OpenShift routes..."
    delete_routes
    echo ""
    
    # Phase 3: Delete ConfigMaps
    log_info "Phase 3: Deleting ConfigMaps..."
    delete_configmaps
    echo ""
    
    # Phase 4: Delete CQL Proxy
    log_info "Phase 4: Deleting CQL Proxy..."
    delete_cql_proxy
    echo ""
    
    # Phase 5: Delete namespace
    log_info "Phase 5: Deleting namespace..."
    delete_namespace
    echo ""
    
    # Phase 6: Verify deletion
    log_info "Phase 6: Verifying cleanup..."
    verify_deletion
    echo ""
    
    # Phase 7: Show remaining resources
    log_info "Phase 7: Checking for remaining resources..."
    show_remaining_resources
    echo ""
    
    log_success "Uninstall completed successfully! 🎉"
    echo ""
    log_info "IBM Lakehouse has been removed from your OpenShift cluster"
}

main "$@"