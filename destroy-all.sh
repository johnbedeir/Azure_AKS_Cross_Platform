#!/bin/bash

####################################################################################################
###                                                                                              ###
###                              AZURE CROSS PLATFORM DESTROY SCRIPT                              ###
###                                                                                              ###
###  This script destroys all infrastructure in the correct order:                                ###
###  1. Cross-Cluster Resources (ArgoCD cluster secrets, Managed Identities)                      ###
###  2. Production Cluster (AKS Production cluster and its components)                          ###
###  3. GitOps Cluster (AKS GitOps cluster and its components)                                  ###
###  4. VPC and Networking (Virtual Network, Subnets, NAT Gateway)                              ###
###  5. Secrets (Azure Key Vault)                                                               ###
###  6. Final Destroy (Catch any remaining resources)                                            ###
###  7. Cleanup Verification                                                                     ###
###                                                                                              ###
####################################################################################################

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print steps
print_step() {
    echo -e "\n${GREEN}====================================================================================${NC}"
    echo -e "${GREEN}[STEP]${NC} $1"
    echo -e "${GREEN}====================================================================================${NC}"
}

# Function to print errors
print_error() {
    echo -e "\n${RED}[ERROR]${NC} $1" >&2
}

# Function to print warnings
print_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
}

# Change to the Terraform directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")
cd "$SCRIPT_DIR"

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    print_error "Azure CLI is not logged in. Please run: az login"
    exit 1
fi

# Get Azure subscription info
AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
AZ_SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")
RESOURCE_GROUP_NAME=$(terraform output -raw azurerm_resource_group.main.name 2>/dev/null || echo "")

# Confirmation prompt
echo -e "${RED}====================================================================================${NC}"
echo -e "${RED}⚠️  WARNING: This will DESTROY ALL AZURE infrastructure!${NC}"
echo -e "${RED}====================================================================================${NC}"
echo ""
echo "This includes:"
echo "  - AKS Production cluster and all its resources"
echo "  - AKS GitOps cluster and all its resources"
echo "  - Virtual Network, Subnets, NAT Gateway, Route Tables"
echo "  - All Managed Identities and Role Assignments"
echo "  - All ArgoCD configurations"
echo ""
echo "Subscription: $AZ_SUBSCRIPTION_NAME"
echo "Subscription ID: $AZ_SUBSCRIPTION_ID"
if [ -n "$RESOURCE_GROUP_NAME" ]; then
    echo "Resource Group: $RESOURCE_GROUP_NAME"
fi
echo ""
read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destroy cancelled."
    exit 0
fi

####################################################################################################
### STEP 1: Destroy Cross-Cluster Resources                                                      ###
####################################################################################################

print_step "Step 1: Destroying ArgoCD cross-cluster resources..."
echo "This includes:"
echo "  - ArgoCD cluster secret for Production cluster"
echo "  - Cross-cluster Managed Identities and Role Assignments"
echo ""

# Try to destroy cross-cluster resources (may not exist if using different method)
terraform destroy -target=module.aks_gitops.kubernetes_secret.argocd_prod_cluster \
                  -auto-approve 2>&1 || print_warning "ArgoCD secret may not exist or already destroyed"

# Destroy cross-cluster Managed Identities
terraform destroy -target=module.aks_gitops.azurerm_user_assigned_identity.argocd_cross_cluster_access \
                  -target=module.aks_gitops.azurerm_role_assignment.argocd_cross_cluster_aks \
                  -target=module.aks.azurerm_user_assigned_identity.argocd_gitops_access \
                  -target=module.aks.azurerm_role_assignment.argocd_gitops_aks \
                  -auto-approve 2>&1 || print_warning "Cross-cluster Managed Identities may not exist or already destroyed"
echo ""

####################################################################################################
### STEP 2: Destroy Production Cluster                                                           ###
####################################################################################################

print_step "Step 2: Destroying AKS Production Cluster and its components..."
echo "This includes:"
echo "  - AKS Production Cluster"
echo "  - Node Pools for Production"
echo "  - Managed Identities for Production"
echo "  - Network Security Groups"
echo "  - RBAC configurations"
echo ""

terraform destroy -target=module.aks \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "Production Cluster destroy failed"
    print_warning "You may need to manually clean up resources in Azure portal"
    print_warning "Check for:"
    print_warning "  - LoadBalancers blocking deletion"
    print_warning "  - Node pools stuck in deleting state"
    exit 1
fi
echo ""

####################################################################################################
### STEP 3: Destroy GitOps Cluster                                                               ###
####################################################################################################

print_step "Step 3: Destroying AKS GitOps Cluster and its components..."
echo "This includes:"
echo "  - AKS GitOps Cluster"
echo "  - Node Pools for GitOps"
echo "  - Managed Identities for GitOps"
echo "  - Network Security Groups"
echo "  - ArgoCD, Chartmuseum, Prometheus, Grafana Helm releases"
echo ""

terraform destroy -target=module.aks_gitops \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "GitOps Cluster destroy failed"
    print_warning "You may need to manually clean up resources in Azure portal"
    print_warning "Check for:"
    print_warning "  - LoadBalancers blocking deletion"
    print_warning "  - Node pools stuck in deleting state"
    exit 1
fi
echo ""

####################################################################################################
### STEP 4: Destroy VPC and Networking                                                            ###
####################################################################################################

print_step "Step 4: Destroying Virtual Network and Networking infrastructure..."
echo "This includes:"
echo "  - Network Security Group Associations"
echo "  - Network Security Groups"
echo "  - Route Table Associations"
echo "  - Route Tables"
echo "  - NAT Gateway"
echo "  - Public IP for NAT Gateway"
echo "  - Subnets (Private and Public)"
echo "  - Virtual Network"
echo ""

terraform destroy -target=azurerm_subnet_network_security_group_association.aks_gitops \
                  -target=azurerm_subnet_network_security_group_association.aks_prod \
                  -target=azurerm_network_security_group.aks_nodes \
                  -target=azurerm_subnet_route_table_association.aks_gitops \
                  -target=azurerm_subnet_route_table_association.aks_prod \
                  -target=azurerm_route_table.private \
                  -target=azurerm_subnet_nat_gateway_association.public \
                  -target=azurerm_nat_gateway_public_ip_association.main \
                  -target=azurerm_nat_gateway.main \
                  -target=azurerm_public_ip.nat_gateway \
                  -target=azurerm_subnet.private_aks_gitops \
                  -target=azurerm_subnet.private_aks_prod \
                  -target=azurerm_subnet.public \
                  -target=azurerm_virtual_network.main \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "VNet and Networking destroy failed"
    print_warning "You may need to manually clean up resources in Azure portal"
    print_warning "Check for:"
    print_warning "  - LoadBalancers using subnets"
    print_warning "  - Network interfaces attached to resources"
    print_warning "  - Network Security Groups with dependencies"
    exit 1
fi
echo ""

####################################################################################################
### STEP 5: Destroy Secrets                                                                      ###
####################################################################################################

print_step "Step 5: Destroying Azure Key Vault..."
echo "This includes:"
echo "  - Key Vault access policies"
echo "  - Key Vault"
echo ""

terraform destroy -target=azurerm_key_vault_access_policy.current_user \
                  -target=azurerm_key_vault.main \
                  -target=random_string.suffix \
                  -auto-approve 2>&1 || print_warning "Key Vault and secrets may not exist or already destroyed"
echo ""

####################################################################################################
### STEP 6: Final Destroy (Catch any remaining resources)                                        ###
####################################################################################################

print_step "Step 6: Performing final 'terraform destroy' to catch any remaining resources..."
terraform destroy -auto-approve
if [ $? -ne 0 ]; then
    print_error "Final 'terraform destroy' failed"
    print_warning "Some resources may still exist. Check Azure portal for remaining resources."
    exit 1
fi
echo ""

####################################################################################################
### STEP 7: Cleanup Verification                                                                 ###
####################################################################################################

print_step "Step 7: Verifying cleanup..."

# Get resource group name if available
RESOURCE_GROUP=$(terraform output -raw azurerm_resource_group.main.name 2>/dev/null || echo "$RESOURCE_GROUP_NAME")

# Check for remaining AKS clusters
if [ -n "$RESOURCE_GROUP" ]; then
    REMAINING_CLUSTERS=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMAINING_CLUSTERS" != "0" ]; then
        print_warning "Found $REMAINING_CLUSTERS remaining cluster(s):"
        az aks list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:provisioningState}" -o table 2>/dev/null
        echo ""
        print_warning "You may need to manually delete these clusters:"
        print_warning "  az aks delete --resource-group $RESOURCE_GROUP --name <cluster-name> --yes"
    else
        echo "✅ No remaining AKS clusters found"
    fi
else
    print_warning "Could not determine resource group. Skipping cluster verification."
fi

# Check for remaining Virtual Networks
REMAINING_VNETS=$(az network vnet list --query "[?contains(name, 'aks-vnet')].name" -o tsv 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING_VNETS" != "0" ]; then
    print_warning "Found $REMAINING_VNETS remaining Virtual Network(s):"
    az network vnet list --query "[?contains(name, 'aks-vnet')].{Name:name,ResourceGroup:resourceGroup}" -o table 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these Virtual Networks:"
    print_warning "  az network vnet delete --resource-group <rg-name> --name <vnet-name>"
else
    echo "✅ No remaining Virtual Networks found"
fi

# Check for remaining LoadBalancers
if [ -n "$RESOURCE_GROUP" ]; then
    REMAINING_LBS=$(az network lb list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMAINING_LBS" != "0" ]; then
        print_warning "Found $REMAINING_LBS remaining LoadBalancer(s):"
        az network lb list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,ProvisioningState:provisioningState}" -o table 2>/dev/null
        echo ""
        print_warning "You may need to manually delete these LoadBalancers:"
        print_warning "  az network lb delete --resource-group $RESOURCE_GROUP --name <lb-name>"
    else
        echo "✅ No remaining LoadBalancers found"
    fi
fi

# Check for remaining NAT Gateways
if [ -n "$RESOURCE_GROUP" ]; then
    REMAINING_NATS=$(az network nat gateway list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMAINING_NATS" != "0" ]; then
        print_warning "Found $REMAINING_NATS remaining NAT Gateway(ies):"
        az network nat gateway list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,ProvisioningState:provisioningState}" -o table 2>/dev/null
        echo ""
        print_warning "You may need to manually delete these NAT Gateways:"
        print_warning "  az network nat gateway delete --resource-group $RESOURCE_GROUP --name <nat-name>"
    else
        echo "✅ No remaining NAT Gateways found"
    fi
fi

# Check for remaining Public IPs
if [ -n "$RESOURCE_GROUP" ]; then
    REMAINING_IPS=$(az network public-ip list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'nat-gateway')].name" -o tsv 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMAINING_IPS" != "0" ]; then
        print_warning "Found $REMAINING_IPS remaining Public IP(s):"
        az network public-ip list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'nat-gateway')].{Name:name,IPAddress:ipAddress}" -o table 2>/dev/null
        echo ""
        print_warning "You may need to manually delete these Public IPs:"
        print_warning "  az network public-ip delete --resource-group $RESOURCE_GROUP --name <ip-name>"
    else
        echo "✅ No remaining Public IPs found"
    fi
fi

# Check for remaining Key Vaults
if [ -n "$RESOURCE_GROUP" ]; then
    REMAINING_KVS=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMAINING_KVS" != "0" ]; then
        print_warning "Found $REMAINING_KVS remaining Key Vault(s):"
        az keyvault list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Location:location}" -o table 2>/dev/null
        echo ""
        print_warning "You may need to manually delete these Key Vaults:"
        print_warning "  az keyvault delete --name <vault-name> --resource-group $RESOURCE_GROUP"
    else
        echo "✅ No remaining Key Vaults found"
    fi
fi

echo ""
print_step "Destroy process completed!"
echo ""
echo "📝 Next steps:"
echo "  1. Verify all resources are deleted in Azure portal"
echo "  2. Check for any remaining resources and delete manually if needed"
echo "  3. Optionally delete the Resource Group if it's empty:"
if [ -n "$RESOURCE_GROUP" ]; then
    echo "     az group delete --name $RESOURCE_GROUP --yes --no-wait"
fi
echo "  4. Run 'terraform init' if you want to rebuild"
echo ""

