locals {
  cert_manager_version = var.cert_manager_version
}

resource "time_sleep" "settle_before_cert_manager" {
  create_duration = "30s"
}

resource "kubernetes_namespace" "cert_manager" {
  depends_on = [
    time_sleep.settle_before_cert_manager,
  ]
  metadata {
    name = "cert-manager"
  }
  lifecycle {
    ignore_changes = [
      metadata,
    ]
  }
  provisioner "local-exec" {
    command = <<-EOT
    kubectl get namespace "cert-manager" -o json  \
     | tr -d "\n" \
     | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/"   \
     | kubectl replace --raw /api/v1/namespaces/cert-manager/finalize -f -
    EOT
    when    = destroy
  }
  provisioner "local-exec" {
    command = <<-EOT
      sleep 15
    EOT
    when    = destroy
  }
}

# https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/values.yaml
resource "helm_release" "cert_manager_configured" {
  depends_on = [
    time_sleep.settle_before_cert_manager,
  ]
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = local.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = false
  wait             = false
  wait_for_jobs    = false
  force_update     = true
  timeout          = 1200 # 20m
  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "crds.enabled"
    value = "true"
  }
}
