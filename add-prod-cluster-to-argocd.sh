#!/bin/bash

####################################################################################################
### Add Production Cluster to ArgoCD                                                             ###
####################################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "\n${GREEN}====================================================================================${NC}"
    echo -e "${GREEN}[STEP]${NC} $1"
    echo -e "${GREEN}====================================================================================${NC}"
}

print_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "\n${RED}[ERROR]${NC} $1" >&2
}

# Set subscription
az account set --subscription 4b010d6b-cb27-4476-bac2-b8fb2d8eef6a

# Get cluster names
PROD_CLUSTER_NAME="aks-prod-production"
GITOPS_CLUSTER_NAME="aks-gitops-production"
RESOURCE_GROUP="rg-aks-cross-platform"

print_step "Getting production cluster information..."
PROD_CLUSTER_ENDPOINT=$(az aks show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PROD_CLUSTER_NAME" \
    --query "fqdn" -o tsv 2>/dev/null)

if [ -z "$PROD_CLUSTER_ENDPOINT" ]; then
    print_error "Could not get production cluster endpoint"
    exit 1
fi

print_step "Getting production cluster credentials..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PROD_CLUSTER_NAME" \
    --overwrite-existing \
    --admin 2>/dev/null || az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PROD_CLUSTER_NAME" \
    --overwrite-existing

# Extract CA certificate from kubeconfig (already base64 encoded)
# Try multiple context names that Azure might use
PROD_CA_CERT=$(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="'$PROD_CLUSTER_NAME'")].cluster.certificate-authority-data}' 2>/dev/null || echo "")

if [ -z "$PROD_CA_CERT" ]; then
    # Try current context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [ -n "$CURRENT_CONTEXT" ]; then
        PROD_CA_CERT=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CURRENT_CONTEXT\")].cluster.certificate-authority-data}" 2>/dev/null || echo "")
    fi
fi

if [ -z "$PROD_CA_CERT" ]; then
    # Try first cluster in config
    PROD_CA_CERT=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' 2>/dev/null || echo "")
fi

if [ -z "$PROD_CA_CERT" ]; then
    # Fallback: get from Azure CLI (this is already base64 encoded)
    PROD_CA_CERT=$(az aks show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$PROD_CLUSTER_NAME" \
        --query "kubeConfig[0].clusterCaCertificate" -o tsv 2>/dev/null)
fi

if [ -z "$PROD_CA_CERT" ]; then
    print_error "Could not get CA certificate for production cluster"
    exit 1
fi

print_step "CA certificate extracted (length: ${#PROD_CA_CERT} characters)"

print_step "Creating service account for ArgoCD in production cluster..."
kubectl create serviceaccount argocd-manager -n kube-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create clusterrolebinding argocd-manager-binding \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:argocd-manager \
    --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

print_step "Getting bearer token..."
sleep 2
BEARER_TOKEN=$(kubectl create token argocd-manager -n kube-system --duration=8760h 2>/dev/null || echo "")

if [ -z "$BEARER_TOKEN" ]; then
    print_warning "Could not get bearer token. Creating secret without token (you'll need to add it manually in ArgoCD UI)"
fi

# Switch back to GitOps cluster
print_step "Switching back to GitOps cluster..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GITOPS_CLUSTER_NAME" \
    --overwrite-existing \
    --admin 2>/dev/null || az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GITOPS_CLUSTER_NAME" \
    --overwrite-existing

# Create the secret
CLUSTER_SECRET_NAME=$(echo "$PROD_CLUSTER_NAME" | tr -d '-')
NAME_B64=$(echo -n "$PROD_CLUSTER_NAME" | base64 | tr -d '\n')
SERVER_B64=$(echo -n "https://${PROD_CLUSTER_ENDPOINT}" | base64 | tr -d '\n')

# Create config JSON - CA cert is already base64 encoded from kubeconfig
if [ -n "$BEARER_TOKEN" ] && [ -n "$PROD_CA_CERT" ]; then
    # CA cert is already base64, bearer token needs to be base64 encoded
    BEARER_TOKEN_B64=$(echo -n "$BEARER_TOKEN" | base64 | tr -d '\n')
    CONFIG_JSON=$(echo "{\"bearerToken\":\"$BEARER_TOKEN\",\"tlsClientConfig\":{\"insecure\":false,\"caData\":\"$PROD_CA_CERT\"}}" | base64 | tr -d '\n')
elif [ -n "$PROD_CA_CERT" ]; then
    # CA cert is already base64 encoded, use it directly
    CONFIG_JSON=$(echo "{\"tlsClientConfig\":{\"insecure\":false,\"caData\":\"$PROD_CA_CERT\"}}" | base64 | tr -d '\n')
else
    print_warning "No CA certificate found, using insecure connection (not recommended)"
    CONFIG_JSON=$(echo '{"tlsClientConfig":{"insecure":true}}' | base64 | tr -d '\n')
fi

print_step "Deleting existing ArgoCD cluster secret (if exists)..."
kubectl delete secret ${CLUSTER_SECRET_NAME}-cluster -n argocd 2>/dev/null || true
sleep 2

print_step "Verifying CA certificate..."
if [ -z "$PROD_CA_CERT" ]; then
    print_error "CA certificate is empty! Cannot create cluster secret."
    exit 1
fi
echo "CA certificate length: ${#PROD_CA_CERT} characters"

print_step "Creating ArgoCD cluster secret with correct CA certificate..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_SECRET_NAME}-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
data:
  name: ${NAME_B64}
  server: ${SERVER_B64}
  config: ${CONFIG_JSON}
EOF

if [ $? -eq 0 ]; then
    print_step "Success! Production cluster '$PROD_CLUSTER_NAME' has been added to ArgoCD"
    print_step "Refresh your ArgoCD UI to see the cluster in Settings > Clusters"
else
    print_error "Failed to create ArgoCD cluster secret"
    exit 1
fi

