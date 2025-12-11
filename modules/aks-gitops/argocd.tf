####################################################################################################
###                                                                                              ###
###                                      ARGOCD                                                  ###
###                                                                                              ###
####################################################################################################

locals {
  argocd_values = <<EOF
    server:
      service:
        type: LoadBalancer
        port: 80
        targetPort: 8080
      extraArgs:
        - --insecure
      serviceAccount:
        create: true
        name: argocd-server
    repoServer:
      service:
        port: 8081
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 250m
          memory: 256Mi
      serviceAccount:
        create: true
        name: argocd-repo-server
    applicationController:
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 250m
          memory: 256Mi
      serviceAccount:
        create: true
        name: argocd-application-controller
      configs:
        params:
          server.insecure: true
    rbac:
      create: true
    EOF
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  provider         = helm.gitops
  name             = "${local.cluster_name}-argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.2.4"
  cleanup_on_fail  = true
  namespace        = "argocd"
  create_namespace = true
  timeout          = 1200
  wait             = false

  values = [local.argocd_values]

  depends_on = [
    azurerm_kubernetes_cluster.gitops_aks,
    azurerm_kubernetes_cluster_node_pool.gitops_prod,
    time_sleep.wait_for_cluster_ready
  ]
}

# Create ArgoCD cluster secret for production cluster
resource "kubernetes_secret" "argocd_prod_cluster" {
  for_each = var.enable_argocd && var.target_cluster_name != "" ? { "prod-cluster" = true } : {}

  provider = kubernetes.gitops

  metadata {
    name      = "${replace(var.target_cluster_name, "-", "")}-cluster"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data = {
    # Cluster name (friendly name shown in ArgoCD UI)
    name   = base64encode(var.target_cluster_name)
    server = base64encode("https://${var.target_cluster_endpoint}")
    # CA data is already base64 encoded
    config = base64encode(jsonencode({
      bearerToken = "" # Will be set manually via ArgoCD UI or CLI
      tlsClientConfig = {
        insecure = false
        caData   = var.target_cluster_ca_data
      }
    }))
  }

  depends_on = [
    helm_release.argocd
  ]
}

