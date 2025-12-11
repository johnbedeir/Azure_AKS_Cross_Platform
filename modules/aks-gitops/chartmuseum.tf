####################################################################################################
###                                                                                              ###
###                                      CHARTMUSEUM                                            ###
###                                                                                              ###
####################################################################################################

locals {
  chartmuseum_values = <<EOF
    env:
      open:
        DISABLE_API: false
        STORAGE: local
    service:
      type: LoadBalancer
      name: chartmuseum
      port: 8080
    persistence:
      enabled: true
      accessMode: ReadWriteOnce
      size: ${var.chartmuseum_storage_size}
      storageClass: ${var.chartmuseum_storage_class}
    EOF
}

resource "helm_release" "chartmuseum" {
  count = var.enable_chartmuseum ? 1 : 0

  provider         = helm.gitops
  name             = "chartmuseum"
  repository       = "https://chartmuseum.github.io/charts"
  chart            = "chartmuseum"
  version          = "3.9.1"
  cleanup_on_fail  = true
  namespace        = "chartmuseum"
  create_namespace = true
  wait             = false
  values           = [local.chartmuseum_values]

  depends_on = [
    azurerm_kubernetes_cluster.gitops_aks,
    azurerm_kubernetes_cluster_node_pool.gitops_prod,
    time_sleep.wait_for_cluster_ready
  ]
}

data "kubernetes_service" "chartmuseum" {
  count    = var.enable_chartmuseum ? 1 : 0
  provider = kubernetes.gitops

  metadata {
    name      = "chartmuseum"
    namespace = "chartmuseum"
  }

  depends_on = [
    helm_release.chartmuseum
  ]
}

output "chartmuseum_url" {
  description = "URL of the ChartMuseum service"
  value       = var.enable_chartmuseum ? "http://${data.kubernetes_service.chartmuseum[0].status.0.load_balancer.0.ingress.0.ip}:8080" : ""
}

