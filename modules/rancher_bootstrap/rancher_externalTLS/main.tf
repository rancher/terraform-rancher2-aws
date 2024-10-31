provider "rancher2" {
  api_url   = "https://${local.rancher_domain}"
  bootstrap = true
}

locals {
  rancher_domain          = var.project_domain
  rancher_helm_repository = var.rancher_helm_repository
  rancher_version         = replace(var.rancher_version, "v", "") # don't include the v
}

resource "time_sleep" "settle_before_rancher" {
  depends_on = [
  ]
  create_duration = "30s"
}

resource "helm_release" "rancher" {
  depends_on = [
  ]
  name             = "rancher"
  chart            = "${local.rancher_helm_repository}/rancher-${local.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  force_update     = true
  timeout          = 2400 # 40m

  set {
    name  = "hostname"
    value = local.rancher_domain
  }
  set {
    name  = "replicas"
    value = "2"
  }
  set {
    name  = "bootstrapPassword"
    value = "admin"
  }
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.tls.source"
    value = "secret"
  }
  set {
    name  = "ingress.tls.secretName"
    value = "tls-rancher-ingress"
  }
  set {
    name  = "privateCA"
    value = "true"
  }
  set {
    name  = "agentTLSMode"
    value = "system-store"
  }
}

resource "time_sleep" "settle_after_rancher" {
  depends_on = [
  ]
  create_duration = "120s"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!$%&-_=+"
}

resource "terraform_data" "get_public_cert_info" {
  depends_on = [
  ]
  provisioner "local-exec" {
    command = <<-EOT
      echo | openssl s_client -showcerts -servername ${local.rancher_domain} -connect ${local.rancher_domain}:443 2>/dev/null | openssl x509 -inform pem -noout -text
    EOT
  }
}

resource "rancher2_bootstrap" "admin" {
  depends_on = [
  ]
  password  = random_password.password.result
  telemetry = false
}
