provider "rancher2" {
  api_url   = "https://${local.rancher_domain}"
  bootstrap = true
}

locals {
  rancher_domain            = var.project_domain
  rancher_helm_repo         = var.rancher_helm_repo
  rancher_helm_channel      = var.rancher_helm_channel
  rancher_version           = replace(var.rancher_version, "v", "") # don't include the v
  helm_chart_use_strategy   = var.rancher_helm_chart_use_strategy
  rancher_helm_chart_values = var.rancher_helm_chart_values
  default_hc_values = {
    "hostname"               = local.rancher_domain
    "replicas"               = "1"
    "bootstrapPassword"      = "admin"
    "ingress.enabled"        = "true"
    "ingress.tls.source"     = "secret"
    "ingress.tls.secretName" = "tls-rancher-ingress"
    "privateCA"              = "true"
    "agentTLSMode"           = "system-store"
  }
  helm_chart_values = coalesce( # using coalesce like this essentially gives us a switch function
    (local.helm_chart_use_strategy == "merge" ?
    merge(local.default_hc_values, local.rancher_helm_chart_values) : null),
    (local.helm_chart_use_strategy == "default" ?
    local.default_hc_values : null),
    (local.helm_chart_use_strategy == "provide" ?
    local.rancher_helm_chart_values : null)
  ) # WARNING! Some config is necessary, if the result is an empty string the coalesce will fail
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

# # WARNING! This adds git, yq, and helm to the dependency list!
# resource "terraform_data" "build_chart" {
#   depends_on = [
#     time_sleep.settle_before_rancher,
#   ]
#   provisioner "local-exec" {
#     command = <<-EOT
#       cd ${abspath(path.root)} || true
#       if [ -d chart ]; then
#         rm -rf chart
#       fi
#       mkdir chart
#       cd chart || exit 1
#       ${abspath(path.module)}/build_chart.sh "${local.rancher_version}"
#       cd ${abspath(path.root)} || true
#       mv chart/rancher-${local.rancher_version}.tgz .
#       rm -rf chart
#       ls ${abspath(path.root)}/rancher-${local.rancher_version}.tgz
#     EOT
#   }
# }

# https://github.com/rancher/rancher/blob/main/chart/values.yaml
resource "helm_release" "rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    # terraform_data.build_chart,
  ]
  name             = "rancher"
  chart            = "${local.rancher_helm_repo}/${local.rancher_helm_channel}/rancher-${local.rancher_version}.tgz" # "${path.root}/rancher-${local.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = false
  wait             = false
  wait_for_jobs    = false
  force_update     = true
  timeout          = 1800 # 30m

  dynamic "set" {
    for_each = local.helm_chart_values
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "terraform_data" "wait_for_rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
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

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!$%&-_=+"
}

resource "terraform_data" "get_public_cert_info" {
  depends_on = [
    random_password.password,
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
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

resource "terraform_data" "get_ping" {
  depends_on = [
    random_password.password,
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    helm_release.rancher,
    terraform_data.wait_for_rancher,
    terraform_data.get_public_cert_info,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      check_letsencrypt_ca() {
        # Try to verify a known Let's Encrypt certificate (you can use any valid one)
        if openssl s_client -showcerts -connect letsencrypt.org:443 < /dev/null | openssl x509 -noout -issuer | grep -q "Let's Encrypt"; then
          return 0 # Success
        else
          return 1 # Failure
        fi
      }
      echo "Checking Let's Encrypt CA"
      if check_letsencrypt_ca; then
        echo "Let's Encrypt CA is functioning correctly."
      else
        echo "Error: Let's Encrypt CA is not being used for verification."
        exit 1
      fi
      echo "Checking Cert"
      echo | openssl s_client -showcerts -servername ${local.rancher_domain} -connect "${local.rancher_domain}:443" 2>/dev/null | openssl x509 -inform pem -noout -text || true
      echo "Checking Curl"
      curl "https://${local.rancher_domain}/ping"
    EOT
  }
}

resource "rancher2_bootstrap" "admin" {
  depends_on = [
    random_password.password,
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    helm_release.rancher,
    terraform_data.wait_for_rancher,
    terraform_data.get_public_cert_info,
    terraform_data.get_ping,
  ]
  password = random_password.password.result
}
