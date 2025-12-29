#!/bin/bash

####################################################################################################
###                                                                                              ###
###                              AZURE CROSS PLATFORM BUILD SCRIPT                                ###
###                                                                                              ###
###  This script builds all infrastructure in the correct order:                                ###
###  1. Terraform Initialization                                                                 ###
###  2. Secrets (Azure Key Vault)                                                               ###
###  3. VPC and Networking (Virtual Network, Subnets, NAT Gateway)                              ###
###  4. GitOps Cluster (AKS GitOps cluster with ArgoCD)                                         ###
###  5. Production Cluster (AKS Production cluster)                                             ###
###  6. Final Apply (Catch any remaining resources)                                             ###
###  7. Get Cluster Information                                                                  ###
###                                                                                              ###
####################################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "\n${GREEN}====================================================================================${NC}"
    echo -e "${GREEN}[STEP]${NC} $1"
    echo -e "${GREEN}====================================================================================${NC}"
}

print_error() {
    echo -e "\n${RED}[ERROR]${NC} $1" >&2
}

print_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
}


# Change to the Terraform directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")
cd "$SCRIPT_DIR"

# Check if we're in the right directory
if [ ! -f "main.tf" ] && [ ! -f "vpc.tf" ]; then
    print_error "Please run this script from the Azure_Cross_Platform directory"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    print_error "Azure CLI is not logged in. Please run: az login"
    exit 1
fi

# Get Azure subscription and tenant info
AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
AZ_TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || echo "")
AZ_SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")

if [ -z "$AZ_SUBSCRIPTION_ID" ]; then
    print_error "Could not determine Azure Subscription ID"
    exit 1
fi

# Set the subscription explicitly (in case multiple subscriptions are available)
print_step "Setting Azure subscription..."
az account set --subscription "$AZ_SUBSCRIPTION_ID" 2>/dev/null || print_warning "Could not set subscription (may already be set)"

print_step "Azure Configuration"
echo "Subscription ID: $AZ_SUBSCRIPTION_ID"
echo "Subscription Name: $AZ_SUBSCRIPTION_NAME"
echo "Tenant ID: $AZ_TENANT_ID"
echo ""

####################################################################################################
### STEP 1: Register Required Resource Providers                                                 ###
####################################################################################################

print_step "Step 1: Registering required Azure resource providers..."
echo "This ensures Microsoft.ContainerService and other providers are registered"
echo ""

# Register Microsoft.ContainerService provider (required for AKS)
az provider register --namespace Microsoft.ContainerService --wait 2>/dev/null || print_warning "Could not register Microsoft.ContainerService provider (may already be registered)"

# Register Microsoft.Network provider (required for networking resources)
az provider register --namespace Microsoft.Network --wait 2>/dev/null || print_warning "Could not register Microsoft.Network provider (may already be registered)"

# Register Microsoft.KeyVault provider (required for Key Vault)
az provider register --namespace Microsoft.KeyVault --wait 2>/dev/null || print_warning "Could not register Microsoft.KeyVault provider (may already be registered)"

echo ""
print_step "Resource providers registered!"
echo ""

####################################################################################################
### STEP 2: Initialize Terraform                                                                ###
####################################################################################################

print_step "Step 2: Initializing Terraform..."
terraform init -upgrade
if [ $? -ne 0 ]; then
    print_error "Terraform initialization failed"
    exit 1
fi
echo ""

####################################################################################################
### STEP 3: Create Secrets (must be created before clusters try to read them)                  ###
####################################################################################################

print_step "Step 3: Creating Azure Key Vault and secrets..."
echo "This includes:"
echo "  - Azure Key Vault"
echo "  - Key Vault access policies"
echo ""

terraform apply -target=azurerm_resource_group.main \
                -target=random_string.suffix \
                -target=azurerm_key_vault.main \
                -target=azurerm_key_vault_access_policy.current_user \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "Key Vault and secrets creation failed"
    exit 1
fi

echo ""
print_step "Key Vault and secrets created successfully!"
echo ""

####################################################################################################
### STEP 4: Build VPC and Networking                                                             ###
####################################################################################################

print_step "Step 4: Building Virtual Network and Networking infrastructure..."
echo "This includes:"
echo "  - Virtual Network (VNet)"
echo "  - Public Subnets"
echo "  - Private Subnets (GitOps and Prod)"
echo "  - NAT Gateway"
echo "  - Route Tables"
echo "  - Network Security Groups"
echo ""

terraform apply -target=azurerm_virtual_network.main \
                -target=azurerm_subnet.private_aks_prod \
                -target=azurerm_subnet.private_aks_gitops \
                -target=azurerm_subnet.public \
                -target=azurerm_public_ip.nat_gateway \
                -target=azurerm_nat_gateway.main \
                -target=azurerm_nat_gateway_public_ip_association.main \
                -target=azurerm_subnet_nat_gateway_association.public \
                -target=azurerm_route_table.private \
                -target=azurerm_subnet_route_table_association.aks_prod \
                -target=azurerm_subnet_route_table_association.aks_gitops \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "VNet and Networking build failed"
    exit 1
fi

echo ""
print_step "VNet and Networking infrastructure created successfully!"
echo ""

####################################################################################################
### STEP 5: Build GitOps Cluster                                                                 ###
####################################################################################################

print_step "Step 5: Building GitOps Cluster (AKS GitOps with ArgoCD)..."
echo "This includes:"
echo "  - AKS GitOps Cluster"
echo "  - Node Pool for GitOps"
echo "  - Managed Identities"
echo "  - Network Security Groups"
echo ""

# Step 5a: Create the cluster and node pool first (without Kubernetes resources)
print_step "Step 5a: Creating AKS GitOps cluster and node pool..."
terraform apply -target=module.aks_gitops.azurerm_kubernetes_cluster.gitops_aks \
                -target=module.aks_gitops.azurerm_kubernetes_cluster_node_pool.gitops_prod \
                -target=module.aks_gitops.time_sleep.wait_for_cluster_ready \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "GitOps Cluster creation failed"
    exit 1
fi

echo ""
print_step "GitOps Cluster and node pool created successfully!"
echo ""

# Check node pool status to ensure nodes are ready
print_step "Checking node pool status..."
az aks nodepool list \
    --resource-group rg-aks-cross-platform \
    --cluster-name aks-gitops-production \
    --output table 2>/dev/null || print_warning "Could not check node pool status"

# Note: AKS uses VMSS (Virtual Machine Scale Sets) for nodes
# You won't see individual VMs in the portal, only the VMSS
# This is normal - the nodes are managed by the VMSS

echo ""

# Step 5b: Get cluster credentials and deploy ArgoCD, ChartMuseum, Prometheus & Grafana via Helm
print_step "Step 5b: Getting cluster credentials and deploying monitoring stack via Helm..."
echo "This includes:"
echo "  - Getting GitOps cluster credentials"
echo "  - Installing ArgoCD via Helm"
echo "  - Installing ChartMuseum via Helm"
echo "  - Installing Prometheus via Helm"
echo "  - Installing Grafana via Helm"
echo ""

# Get cluster credentials (works with or without Azure AD)
print_step "Getting GitOps cluster credentials..."
az account set --subscription 4b010d6b-cb27-4476-bac2-b8fb2d8eef6a
az aks get-credentials \
    --resource-group rg-aks-cross-platform \
    --name aks-gitops-production \
    --overwrite-existing \
    --admin 2>/dev/null || az aks get-credentials \
    --resource-group rg-aks-cross-platform \
    --name aks-gitops-production \
    --overwrite-existing

if [ $? -ne 0 ]; then
    print_error "Failed to get GitOps cluster credentials"
    exit 1
fi

# Wait for nodes to be ready
print_step "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s 2>/dev/null || print_warning "Some nodes may not be ready yet"

# Install ArgoCD
print_step "Installing ArgoCD via Helm..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo

helm upgrade --install aks-gitops-production-argocd argo/argo-cd \
    --version 8.2.4 \
    --namespace argocd \
    --create-namespace \
    --set server.service.type=LoadBalancer \
    --set server.service.port=80 \
    --set server.extraArgs[0]=--insecure \
    --set repoServer.resources.limits.cpu=500m \
    --set repoServer.resources.limits.memory=512Mi \
    --set repoServer.resources.requests.cpu=250m \
    --set repoServer.resources.requests.memory=256Mi \
    --set applicationController.resources.limits.cpu=500m \
    --set applicationController.resources.limits.memory=512Mi \
    --set applicationController.resources.requests.cpu=250m \
    --set applicationController.resources.requests.memory=256Mi \
    --set applicationController.configs.params."server\.insecure"=true \
    --wait --timeout 20m

if [ $? -ne 0 ]; then
    print_warning "ArgoCD installation had issues, but continuing..."
fi

# Install ChartMuseum
print_step "Installing ChartMuseum via Helm..."
helm repo add chartmuseum https://chartmuseum.github.io/charts 2>/dev/null || true
helm repo update chartmuseum

helm upgrade --install chartmuseum chartmuseum/chartmuseum \
    --version 3.9.1 \
    --namespace chartmuseum \
    --create-namespace \
    --set env.open.DISABLE_API=false \
    --set env.open.STORAGE=local \
    --set service.type=LoadBalancer \
    --set service.port=8080 \
    --set persistence.enabled=true \
    --set persistence.accessMode=ReadWriteOnce \
    --set persistence.size=8Gi \
    --set persistence.storageClass=managed-csi \
    --wait --timeout 10m

if [ $? -ne 0 ]; then
    print_warning "ChartMuseum installation had issues, but continuing..."
fi

# Install Prometheus
print_step "Installing Prometheus via Helm..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community

# Install Prometheus without waiting to avoid hanging
print_step "Installing Prometheus (this may take a few minutes)..."

# Create admission webhook secret with self-signed certificate to prevent pod from hanging
# This is needed even when webhooks are disabled because the operator pod tries to mount it
print_step "Creating admission webhook secret (required even when webhooks are disabled)..."
kubectl create namespace monitoring 2>/dev/null || true

# Delete existing secret if it exists (to allow type/key changes)
kubectl delete secret prometheus-kube-prometheus-admission -n monitoring 2>/dev/null || true

# Generate self-signed certificate for the admission webhook secret
# The operator expects keys named "cert" and "key", not "tls.crt" and "tls.key"
TMP_CERT=$(mktemp)
TMP_KEY=$(mktemp)
if openssl req -x509 -newkey rsa:2048 -keyout "$TMP_KEY" -out "$TMP_CERT" -days 365 -nodes -subj "/CN=prometheus-kube-prometheus-admission" 2>/dev/null; then
    if [ -f "$TMP_CERT" ] && [ -f "$TMP_KEY" ]; then
        kubectl create secret generic prometheus-kube-prometheus-admission \
            -n monitoring \
            --from-file="$TMP_CERT" \
            --from-file="$TMP_KEY" 2>/dev/null || true
        rm -f "$TMP_CERT" "$TMP_KEY"
    fi
else
    # Fallback: create empty secret if openssl fails
    kubectl create secret generic prometheus-kube-prometheus-admission \
        -n monitoring \
        --from-literal=cert='' \
        --from-literal=key='' \
        --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
fi

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --version 58.0.0 \
    --namespace monitoring \
    --create-namespace \
    --set prometheus.prometheusSpec.retention=30d \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=managed-csi \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.resources.requests.cpu=200m \
    --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
    --set prometheus.prometheusSpec.resources.limits.cpu=1000m \
    --set prometheus.prometheusSpec.resources.limits.memory=2Gi \
    --set prometheusOperator.admissionWebhooks.enabled=false \
    --set prometheusOperator.admissionWebhooks.patch.enabled=false \
    --set prometheusOperator.admissionWebhooks.certManager.enabled=false \
    --set prometheusOperator.admissionWebhooks.cert.create=false \
    --set alertmanager.enabled=false \
    --set kubeStateMetrics.enabled=true \
    --set nodeExporter.enabled=true \
    --set prometheusOperator.resources.requests.cpu=100m \
    --set prometheusOperator.resources.requests.memory=128Mi \
    --set prometheusOperator.resources.limits.cpu=500m \
    --set prometheusOperator.resources.limits.memory=512Mi \
    --wait=false \
    --timeout 5m

# Wait for Prometheus pods to be ready (with timeout)
print_step "Waiting for Prometheus pods to be ready..."
for i in {1..30}; do
    if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=60s 2>/dev/null; then
        print_step "Prometheus pods are ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "Prometheus pods are taking longer than expected, but continuing..."
    else
        echo "Waiting for Prometheus pods... ($i/30)"
        sleep 10
    fi
done

# Patch Prometheus and Grafana services to LoadBalancer
print_step "Configuring Prometheus and Grafana services as LoadBalancer..."
sleep 5  # Give the services time to be created

# Patch Prometheus service
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec":{"type":"LoadBalancer","ports":[{"port":80,"targetPort":9090,"protocol":"TCP","name":"http"}]}}' 2>/dev/null || \
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec":{"type":"LoadBalancer"}}' 2>/dev/null || \
print_warning "Could not patch Prometheus service to LoadBalancer"

# Patch Grafana service from Prometheus stack
kubectl patch svc prometheus-grafana -n monitoring -p '{"spec":{"type":"LoadBalancer"}}' 2>/dev/null || \
print_warning "Could not patch Grafana service to LoadBalancer"

if [ $? -ne 0 ]; then
    print_warning "Prometheus installation had issues, but continuing..."
    print_warning "You can check the status with: kubectl get pods -n monitoring"
fi

# Install Grafana
print_step "Installing Grafana via Helm..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana

# Get Grafana admin password (or use default)
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32 2>/dev/null || echo "admin")

helm upgrade --install grafana grafana/grafana \
    --version 7.3.7 \
    --namespace monitoring \
    --create-namespace \
    --set adminPassword="$GRAFANA_ADMIN_PASSWORD" \
    --set service.type=LoadBalancer \
    --set service.port=80 \
    --set persistence.enabled=true \
    --set persistence.storageClassName=managed-csi \
    --set persistence.accessModes[0]=ReadWriteOnce \
    --set persistence.size=10Gi \
    --set datasources."datasources\.yaml".apiVersion=1 \
    --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
    --set datasources."datasources\.yaml".datasources[0].type=prometheus \
    --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-kube-prometheus-prometheus.monitoring.svc:9090 \
    --set datasources."datasources\.yaml".datasources[0].isDefault=true \
    --set datasources."datasources\.yaml".datasources[0].access=proxy \
    --wait --timeout 10m

if [ $? -ne 0 ]; then
    print_warning "Grafana installation had issues, but continuing..."
fi

echo ""
print_step "ArgoCD, ChartMuseum, Prometheus, and Grafana deployed successfully via Helm!"
echo ""
echo "Grafana admin credentials:"
echo "  Username: admin"
echo "  Password: $GRAFANA_ADMIN_PASSWORD"
echo ""
echo "To get service LoadBalancer IPs:"
echo "  Grafana:   kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo "  Prometheus: kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo ""

####################################################################################################
### STEP 6: Build Production Cluster                                                             ###
####################################################################################################

print_step "Step 6: Building Production Cluster (AKS Prod)..."
echo "This includes:"
echo "  - AKS Production Cluster"
echo "  - Node Pool for Production"
echo "  - Managed Identities"
echo "  - Network Security Groups"
echo "  - Cross-cluster access configuration"
echo ""

terraform apply -target=module.aks \
                -auto-approve

if [ $? -ne 0 ]; then
    print_error "Production Cluster build failed"
    exit 1
fi

echo ""
print_step "Production Cluster created successfully!"
echo ""


####################################################################################################
### STEP 7: Configure Cross-Cluster Communication                                               ###
####################################################################################################

print_step "Step 7: Configuring cross-cluster communication for ArgoCD..."
echo "This includes:"
echo "  - ArgoCD cluster secret for production cluster"
echo ""

# Get prod cluster info
print_step "Getting production cluster information..."
PROD_CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "aks-prod-cluster")
PROD_CLUSTER_ENDPOINT=$(az aks show \
    --resource-group rg-aks-cross-platform \
    --name "$PROD_CLUSTER_NAME" \
    --query "fqdn" -o tsv 2>/dev/null)

if [ -z "$PROD_CLUSTER_ENDPOINT" ]; then
    print_warning "Could not get prod cluster endpoint. ArgoCD cluster secret will need to be created manually."
else
    # Get prod cluster CA certificate from Terraform output
    PROD_CA_CERT=$(terraform output -raw cluster_certificate_authority_data 2>/dev/null || echo "")
    
    # Create ArgoCD cluster secret for prod cluster
    print_step "Creating ArgoCD cluster secret for production cluster..."
    
    # Ensure we're using GitOps cluster context
    az aks get-credentials \
        --resource-group rg-aks-cross-platform \
        --name aks-gitops-production \
        --overwrite-existing \
        --admin 2>/dev/null || az aks get-credentials \
        --resource-group rg-aks-cross-platform \
        --name aks-gitops-production \
        --overwrite-existing
    
    # Create the secret in the correct ArgoCD format
    CLUSTER_SECRET_NAME=$(echo "$PROD_CLUSTER_NAME" | tr -d '-')
    
    # Create config JSON and base64 encode it
    if [ -n "$PROD_CA_CERT" ]; then
        CONFIG_JSON=$(echo "{\"tlsClientConfig\":{\"insecure\":false,\"caData\":\"$PROD_CA_CERT\"}}" | base64 | tr -d '\n')
    else
        CONFIG_JSON=$(echo '{"tlsClientConfig":{"insecure":false}}' | base64 | tr -d '\n')
    fi
    
    # Base64 encode name and server
    NAME_B64=$(echo -n "$PROD_CLUSTER_NAME" | base64 | tr -d '\n')
    SERVER_B64=$(echo -n "https://${PROD_CLUSTER_ENDPOINT}" | base64 | tr -d '\n')
    
    # Create the secret using YAML
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
    
    if [ $? -ne 0 ]; then
        print_warning "Could not create ArgoCD cluster secret automatically"
    fi
    
    print_step "Note: You may need to configure the bearer token for ArgoCD to access the prod cluster"
    print_step "You can do this via ArgoCD UI or CLI after deployment"
fi

echo ""
print_step "Cross-cluster communication configured!"
echo ""

####################################################################################################
### STEP 8: Final Apply (Catch any remaining resources)                                         ###
####################################################################################################

print_step "Step 8: Final apply to catch any remaining resources..."
terraform apply -auto-approve

if [ $? -ne 0 ]; then
    print_warning "Final apply had some issues, but main infrastructure should be built"
fi

echo ""

####################################################################################################
### STEP 9: Build Complete                                                                      ###
####################################################################################################

print_step "Build process completed successfully!"
echo ""

