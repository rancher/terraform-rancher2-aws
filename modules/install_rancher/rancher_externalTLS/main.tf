locals {
  rancher_domain            = var.project_domain
  rancher_helm_repo         = var.rancher_helm_repo
  rancher_helm_channel      = var.rancher_helm_channel
  rancher_version           = replace(var.rancher_version, "v", "") # don't include the v
  helm_chart_use_strategy   = var.rancher_helm_chart_use_strategy
  rancher_helm_chart_values = jsondecode(base64decode(var.rancher_helm_chart_values))
  public_cert               = base64decode(var.public_cert)
  private_key               = base64decode(var.private_key)
  ca_certs                  = base64decode(var.ca_certs)
  full_chain                = <<-EOT
    ${trimspace(local.public_cert)}
    ${trimspace(local.ca_certs)}
  EOT
  default_hc_values = {
    "hostname"               = local.rancher_domain # must be an fqdn
    "replicas"               = "3"
    "bootstrapPassword"      = random_password.admin_password.result
    "ingress.enabled"        = "true"
    "ingress.tls.source"     = "secret"
    "ingress.tls.secretName" = "tls-rancher-ingress"
    "privateCA"              = "true"
    "agentTLSMode"           = "strict"
    "additionalTrustedCAs"   = "true"
  }
  helm_chart_values = coalesce( # using coalesce like this essentially gives us a switch function
    (local.helm_chart_use_strategy == "default" ? local.default_hc_values : null),
    (local.helm_chart_use_strategy == "merge" ? merge(local.default_hc_values, local.rancher_helm_chart_values) : null),
    (local.helm_chart_use_strategy == "provide" ? local.rancher_helm_chart_values : null),
  ) # WARNING! helm_chart_use_strategy is required and must be "default", "merge", or "provide", if the strategy isn't found, the coalesce will fail
  default_admin_password = "admin"
  bootstrap_password     = (local.helm_chart_values["bootstrapPassword"] != "" ? local.helm_chart_values["bootstrapPassword"] : local.default_admin_password)
}

resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%-_=+"
}

resource "file_local" "hcv" {
  name     = "helm_chart_values.txt"
  contents = jsonencode(local.rancher_helm_chart_values)
}
resource "file_local" "pc" {
  name     = "public.cert"
  contents = local.public_cert
}
resource "file_local" "ca" {
  name     = "ca.cert"
  contents = local.ca_certs
}
resource "file_local" "key" {
  name     = "private.key"
  contents = local.private_key
}

resource "time_sleep" "settle_before_rancher" {
  create_duration = "30s"
}

resource "terraform_data" "wait_for_nginx" {
  depends_on = [
    time_sleep.settle_before_rancher,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      EXITCODE=1
      ATTEMPTS=0
      MAX=5
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        timeout 3600 kubectl rollout status daemonset -n kube-system rke2-ingress-nginx-controller --timeout=60s
        EXITCODE=$?
        if [ $EXITCODE -gt 0 ]; then
          timeout 3600 kubectl get pods -A
        fi
        ATTEMPTS=$((ATTEMPTS+1))
      done
      exit $EXITCODE
    EOT
  }
}

# uses kubectl to idempotentenly create cattle-system namespace
resource "terraform_data" "cattle-system" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      kubectl get namespace cattle-system || kubectl create namespace cattle-system
    EOT
  }
  provisioner "local-exec" {
    command = <<-EOT
    kubectl get namespace "cattle-system" -o json  \
     | tr -d "\n" \
     | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/"   \
     | kubectl replace --raw /api/v1/namespaces/cattle-system/finalize -f -
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

resource "kubernetes_secret" "tls_rancher_ingress" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
  ]
  metadata {
    name      = "tls-rancher-ingress"
    namespace = "cattle-system"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = local.full_chain,
    "tls.key" = local.private_key,
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

resource "kubernetes_secret" "rancher_tls_ca" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_secret.tls_rancher_ingress,
  ]
  metadata {
    name      = "tls-ca"
    namespace = "cattle-system"
  }
  type = "generic"
  data = {
    "cacerts.pem" = local.ca_certs
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

resource "kubernetes_secret" "rancher_tls_ca_additional" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_secret.tls_rancher_ingress,
    kubernetes_secret.rancher_tls_ca,
  ]
  metadata {
    name      = "tls-ca-additional"
    namespace = "cattle-system"
  }
  type = "generic"
  data = {
    "ca-additional.pem" = local.ca_certs,
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

# https://github.com/rancher/rancher/blob/main/chart/values.yaml
resource "helm_release" "rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_secret.tls_rancher_ingress,
    kubernetes_secret.rancher_tls_ca,
    kubernetes_secret.rancher_tls_ca_additional,
  ]
  name             = "rancher"
  chart            = "${local.rancher_helm_repo}/${local.rancher_helm_channel}/rancher-${local.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = false
  wait             = false
  wait_for_jobs    = false
  force_update     = true
  timeout          = 1800 # 30m

  dynamic "set" {
    # Terraform won't iterate over sensitive values, so we have to wrap it in nonsensitive()
    for_each = nonsensitive(local.helm_chart_values)
    content {
      name  = set.key
      type  = "string"
      value = set.value
    }
  }
}

resource "terraform_data" "wait_for_rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_secret.tls_rancher_ingress,
    kubernetes_secret.rancher_tls_ca,
    kubernetes_secret.rancher_tls_ca_additional,
    helm_release.rancher,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      cd ${abspath(path.root)} || true
      chmod +x ${abspath(path.module)}/runningPods.sh
      echo "using kubeconfig located at $KUBECONFIG"
      ${abspath(path.module)}/runningPods.sh
    EOT
  }
}

resource "terraform_data" "get_public_cert_info" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_secret.tls_rancher_ingress,
    kubernetes_secret.rancher_tls_ca,
    kubernetes_secret.rancher_tls_ca_additional,
    helm_release.rancher,
    terraform_data.wait_for_rancher,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      CERT="$(echo | openssl s_client -showcerts -servername ${local.rancher_domain} -connect ${local.rancher_domain}:443 2>/dev/null | openssl x509 -inform pem -noout -text)"
      echo "$CERT"
      FAKE="$(echo "$CERT" | grep 'Kubernetes Ingress Controller Fake Certificate')"
      if [ -z "$FAKE" ]; then
        echo "cert is not fake"
        exit 0
      else
        echo "cert is fake"
        exit 1
      fi
    EOT
  }
}
