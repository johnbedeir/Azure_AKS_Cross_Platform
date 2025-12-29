# Azure-AKS-Cross-Platform

<img src="cover.png">

A Terraform-based infrastructure as code project for deploying Azure Kubernetes Service (AKS) clusters with GitOps capabilities using ArgoCD. This project creates two AKS clusters: a Production cluster and a GitOps cluster for managing deployments.

## 🏗️ Architecture

- **Production Cluster (`aks-prod-production`)**: Main cluster for running production workloads
- **GitOps Cluster (`aks-gitops-production`)**: Cluster running ArgoCD for GitOps-based deployments
- **Virtual Network (VNet)**: Private networking with NAT Gateway for outbound internet access
- **Managed Identities**: Azure Managed Identity integration for secure authentication
- **ArgoCD**: GitOps tool for continuous deployment from Git repositories
- **ChartMuseum**: Helm chart repository for storing and serving Helm charts
- **Prometheus**: Metrics collection and alerting (kube-prometheus-stack)
- **Grafana**: Visualization and dashboards (included with Prometheus stack + standalone installation)

## 📋 Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.7
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) configured with appropriate credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0
- Azure Account with appropriate permissions
- Required Azure services enabled:
  - AKS (Azure Kubernetes Service)
  - Virtual Network (for networking)
  - Key Vault (for secrets management)
  - Load Balancer (for ArgoCD and ChartMuseum)

## 🚀 Quick Start

### 1. Configure Terraform Variables

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:

- `subscription_id`: Your Azure Subscription ID
- `tenant_id`: Your Azure Tenant ID
- `admin_users`: Your Azure AD object IDs (for cluster access)

### 2. Deploy Infrastructure

Run the build script to deploy all infrastructure in the correct order:

```bash
./build-all.sh
```

This script will:

1. Register required Azure resource providers
2. Initialize Terraform
3. Create Azure Key Vault
4. Build VPC and networking infrastructure (Virtual Network, Subnets, NAT Gateway)
5. Deploy GitOps cluster with ArgoCD, ChartMuseum, Prometheus, and Grafana
6. Deploy Production cluster
7. Configure cross-cluster communication for ArgoCD

**Expected time:** 20-30 minutes

### 3. Configure ArgoCD Cross-Cluster Access

After the build completes, you need to add the Production cluster to ArgoCD. Run the provided script:

```bash
./add-prod-cluster-to-argocd.sh
```

This script will:

1. Get production cluster credentials
2. Create a service account in the production cluster for ArgoCD
3. Get a bearer token for authentication
4. Create the ArgoCD cluster secret in the GitOps cluster

Alternatively, you can verify the cluster connection manually:

1. Access ArgoCD UI (see Step 4 below)
2. Go to **Settings** → **Clusters**
3. Verify `aks-prod-production` cluster is listed and shows as "Connected"
4. If not connected, check the cluster secret:

```bash
# Switch to GitOps cluster
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-gitops-production --overwrite-existing

# Check cluster secret
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster

# Restart ArgoCD controller if needed
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Wait 30 seconds** for the ArgoCD controller to restart.

### 4. Access ArgoCD UI

Get the ArgoCD LoadBalancer IP:

```bash
# Switch to GitOps cluster
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-gitops-production --overwrite-existing

# Get LoadBalancer IP
kubectl get svc -n argocd aks-gitops-production-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Get the ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access ArgoCD UI at `http://<LOADBALANCER_IP>` (use the password from above, username is `admin`)

**Note:** The LoadBalancer uses HTTP (port 80) for simplicity. For production, consider configuring HTTPS.

## 🧪 Testing with Hello World Helm Chart

### Step 1: Authenticate with Clusters

Authenticate with both clusters to verify access:

```bash
# Authenticate with Production cluster
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-prod-production --overwrite-existing

# Authenticate with GitOps cluster
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-gitops-production --overwrite-existing
```

### Step 2: Create Namespace on Production Cluster

Switch to the Production cluster context and create a test namespace:

```bash
# Ensure you're using the prod cluster
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-prod-production --overwrite-existing

# Create test namespace
kubectl create namespace test
```

### Step 3: Add Helm Repository in ArgoCD

1. Open ArgoCD UI (from Step 4 above)
2. Go to **Settings** → **Repositories**
3. Click **Connect Repo**
4. Fill in:
   - **Type**: Helm
   - **Name**: `hello-world` (or any name)
   - **URL**: `https://charts.bitnami.com/bitnami` (Bitnami charts repository)
   - **Enable OCI**: Leave unchecked
5. Click **Connect**

### Step 4: Create Application in ArgoCD

1. In ArgoCD UI, click **New App** or the **+** button
2. Fill in the application details:

   **General:**

   - **Application Name**: `hello-world`
   - **Project Name**: `default`
   - **Sync Policy**: `Manual` or `Automatic`

   **Source:**

   - **Repository**: Select the repository you just added in Step 3 from the dropdown (e.g., `hello-world` or the name you used)
     - The repository should appear in the dropdown since you connected it in Step 3
     - If it doesn't appear, go back to **Settings** → **Repositories** and verify it's connected
   - **Chart**: `nginx` (or any chart from Bitnami)
   - **Version**: `*` (latest) or specific version like `15.0.0`
   - **Helm**: Leave default values or add custom values

   **Destination:**

   - **Cluster URL**: Select the Production cluster (`aks-prod-production` or its endpoint) from the dropdown
     - If the Production cluster doesn't appear in the dropdown:
       - Go to **Settings** → **Clusters**
       - Verify `aks-prod-production` cluster is listed and shows as "Connected"
       - If not connected, run `./add-prod-cluster-to-argocd.sh` again
   - **Namespace**: `test` (the namespace you created on Production cluster)

3. Click **Create**
4. Click **Sync** to deploy the application to the Production cluster

### Step 5: Verify Deployment

Check the application status in ArgoCD UI or via CLI:

```bash
# Switch to GitOps cluster
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-gitops-production --overwrite-existing

# Check application status
kubectl get application hello-world -n argocd

# Switch to Production cluster and verify pods
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-prod-production --overwrite-existing
kubectl get pods -n test
kubectl get svc -n test
```

## 🗑️ Destroy Infrastructure

To destroy all infrastructure:

```bash
./destroy-all.sh
```

This script will:

1. Ask for confirmation (type `yes` to confirm)
2. Destroy ArgoCD cross-cluster resources (secrets, Managed Identities)
3. Destroy Production cluster and node pools
4. Destroy GitOps cluster and node pools
5. Destroy VNet and networking (route tables, NAT Gateway, subnets, VNet)
6. Destroy secrets in Azure Key Vault
7. Perform final cleanup
8. Verify all resources are deleted

**Warning:** This will delete all resources. Make sure you have backups if needed.

**Note:** If you encounter dependency errors during destroy (e.g., LoadBalancers blocking subnet deletion), you may need to manually delete LoadBalancers first:

```bash
# List LoadBalancers
az network lb list --resource-group rg-aks-cross-platform

# Delete LoadBalancers if needed
az network lb delete --name <NAME> --resource-group rg-aks-cross-platform
```

## 📁 Project Structure

```
Azure_Cross_Platform/
├── modules/
│   ├── aks-prod/              # Production AKS cluster module
│   │   ├── aks.tf             # AKS cluster definition
│   │   ├── node_pool.tf       # Node pool configuration
│   │   ├── networking.tf       # Network Security Groups
│   │   ├── service_accounts.tf # Managed Identities
│   │   ├── metrics-server.tf  # Metrics Server
│   │   ├── clusterautoscaler.tf # Cluster Autoscaler
│   │   └── ...
│   └── aks-gitops/            # GitOps AKS cluster module
│       ├── aks.tf              # AKS cluster definition
│       ├── node_pool.tf        # Node pool configuration
│       ├── argocd.tf           # ArgoCD Terraform resources (deprecated - now installed via Helm)
│       ├── chartmuseum.tf     # ChartMuseum Terraform resources (deprecated - now installed via Helm)
│       ├── cross_cluster.tf    # Cross-cluster Managed Identities
│       ├── service_accounts.tf # Service accounts and Managed Identities
│       ├── networking.tf      # Network Security Groups
│       └── ...
├── vpc.tf                      # Virtual Network definition
├── subnet-aks.tf               # Production AKS subnets
├── subnet-aks-gitops.tf        # GitOps AKS subnets
├── subnet-public.tf            # Public subnets
├── aks.tf                      # Production cluster module call
├── aks-gitops.tf               # GitOps cluster module call
├── secrets.tf                  # Azure Key Vault secrets
├── terraform.tfvars            # Variable values (not in git)
├── terraform.tfvars.example    # Example variables file
├── build-all.sh                # Build script
├── destroy-all.sh              # Destroy script
└── add-prod-cluster-to-argocd.sh # Script to add prod cluster to ArgoCD
```

## 🔧 Configuration

### Node Pool Sizes

Default configuration:

- **Production**: 1 node (configurable in `terraform.tfvars`)
- **GitOps**: 2 nodes (configurable in `terraform.tfvars`)

Adjust in `terraform.tfvars`:

- `node_pool_new_desired_size`: Production desired nodes
- `node_pool_new_min_size`: Production minimum nodes
- `node_pool_new_max_size`: Production maximum nodes
- `gitops_node_pool_desired_size`: GitOps desired nodes
- `gitops_node_pool_min_size`: GitOps minimum nodes
- `gitops_node_pool_max_size`: GitOps maximum nodes

### Networking

- **VNet CIDR**: `10.0.0.0/16`
- **Production Subnets**: `10.0.1.0/24`, `10.0.2.0/24` (256 IPs each)
- **GitOps Subnets**: `10.0.10.0/24`, `10.0.11.0/24` (256 IPs each)
- **Public Subnets**: `10.0.101.0/24`, `10.0.102.0/24` (for NAT Gateway and LoadBalancers)

### Network Security Groups (NSG)

The GitOps cluster NSG includes rules for:

- **HTTP (port 80)**: Allowed from internet for ArgoCD, ChartMuseum, Prometheus, and Grafana LoadBalancers
- **HTTPS (port 443)**: Allowed from VNet and internet for cluster API access
- **Cluster API (port 10250)**: Allowed for cluster communication

### Cluster Access

Clusters use public API servers with nodes in private subnets. Access to clusters is controlled via:

- Azure AD integration (for user authentication)
- Managed Identities (for service-to-service authentication)
- Kubernetes RBAC

## 🔐 Security

- **Private Subnets**: Nodes have private IPs only
- **NAT Gateway**: Outbound internet access for nodes
- **Managed Identities**: Service-to-service authentication without secrets
- **Network Security Groups**: Network-level security controls
- **RBAC**: Kubernetes RBAC configured
- **Secrets**: Azure Key Vault for secure secret storage
- **LoadBalancer**: Standard SKU LoadBalancers for production workloads

## 📊 Monitoring

- **Prometheus**: Metrics collection and alerting deployed on GitOps cluster (kube-prometheus-stack)
- **Grafana**: Visualization and dashboards deployed on GitOps cluster
  - **Prometheus Stack Grafana**: Included with kube-prometheus-stack (service: `prometheus-grafana`)
  - **Standalone Grafana**: Separate installation with Prometheus pre-configured as datasource (service: `grafana`)
- **Azure Monitor**: Automatic log collection (if configured)
- **Metrics Server**: Resource metrics for autoscaling
- **Cluster Autoscaler**: Automatic node scaling based on workload

### Accessing Prometheus

After deployment, get the Prometheus LoadBalancer IP:

```bash
# Switch to GitOps cluster
az aks get-credentials --resource-group rg-aks-cross-platform --name aks-gitops-production --overwrite-existing

# Get Prometheus LoadBalancer IP
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Access Prometheus UI at `http://<LOADBALANCER_IP>` (port 80 maps to internal port 9090).

### Accessing Grafana

After deployment, you can access Grafana via either service:

**Option 1: Prometheus Stack Grafana** (recommended - pre-configured with Prometheus):

```bash
# Get Prometheus Stack Grafana LoadBalancer IP
kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Default credentials:

- **Username**: `admin`
- **Password**: `prom-operator` (default for kube-prometheus-stack Grafana)

**Option 2: Standalone Grafana** (with custom password):

```bash
# Get Standalone Grafana LoadBalancer IP
kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

The admin password for standalone Grafana is generated during installation and displayed in the build script output. Default username is `admin`.

**Note:** Both Grafana services are accessible on port 80 via LoadBalancer. The standalone Grafana has Prometheus pre-configured as the default datasource.
