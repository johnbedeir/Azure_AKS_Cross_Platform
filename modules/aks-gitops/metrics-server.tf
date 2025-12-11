####################################################################################################
###                                                                                              ###
###                                      METRICS SERVER                                          ###
###                                                                                              ###
####################################################################################################

# Metrics Server deployment using Helm
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  provider         = helm.gitops
  name             = "${local.cluster_name}-metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  timeout          = 600 # 10 minutes timeout
  wait             = true

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  depends_on = [
    azurerm_kubernetes_cluster.gitops_aks,
    azurerm_kubernetes_cluster_node_pool.gitops_prod,
    time_sleep.wait_for_cluster_ready
  ]
}

