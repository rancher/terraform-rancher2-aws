locals {
  cert_manager_version = var.cert_manager_version
}

resource "time_sleep" "settle_before_cert_manager" {
  create_duration = "30s"
}

# https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/values.yaml
resource "helm_release" "cert_manager_unconfigured" {
  depends_on = [
    time_sleep.settle_before_cert_manager,
  ]
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = local.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  force_update     = true
  timeout          = 1200 # 20m

  set {
    name  = "installCRDs"
    value = "true"
  }
}
