locals {
  cert_manager_version = var.cert_manager_version
  cert_manager_config  = var.cert_manager_configuration
  zone                 = var.zone
  zone_id              = var.zone_id
}

resource "time_sleep" "settle_before_cert_manager" {
  create_duration = "30s"
}

# uses kubectl to idempotentenly create cert-manager namespace
resource "terraform_data" "cert_manager" {
  depends_on = [
    time_sleep.settle_before_cert_manager,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      kubectl get namespace cert-manager || kubectl create namespace cert-manager
    EOT
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
    terraform_data.cert_manager,
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
    name  = "crds.enabled"
    value = "true"
  }
  set {
    name  = "extraEnv[0].name"
    value = "AWS_REGION"
  }
  set {
    name  = "extraEnv[0].value"
    value = local.cert_manager_config.aws_region
  }
  set {
    name  = "extraEnv[1].name"
    value = "AWS_ACCESS_KEY_ID"
  }
  set {
    name  = "extraEnv[1].value"
    value = local.cert_manager_config.aws_access_key_id
  }
  set {
    name  = "extraEnv[2].name"
    value = "AWS_SECRET_ACCESS_KEY"
  }
  set {
    name  = "extraEnv[2].value"
    value = local.cert_manager_config.aws_secret_access_key
  }
  set {
    name  = "extraEnv[3].name"
    value = (local.cert_manager_config.aws_session_token != "" ? "AWS_SESSION_TOKEN" : "DUMMY")
  }
  set {
    name  = "extraEnv[3].value"
    value = local.cert_manager_config.aws_session_token
  }
  set {
    name  = "extraEnv[4].name"
    value = "AWS_HOSTED_ZONE"
  }
  set {
    name  = "extraEnv[4].value"
    value = local.zone
  }
  set {
    name  = "extraEnv[5].name"
    value = "AWS_HOSTED_ZONE_ID"
  }
  set {
    name  = "extraEnv[5].value"
    value = local.zone_id
  }
  set {
    name  = "extraArgs[0]"
    value = "--issuer-ambient-credentials"
  }
  set {
    name  = "extraArgs[1]"
    value = "--cluster-resource-namespace=cattle-system"
  }
}
