provider "rancher2" {
  api_url   = "https://${local.rancher_domain}"
  bootstrap = true
}

locals {
  rancher_domain  = var.project_domain
  rancher_version = replace(var.rancher_version, "v", "") # don't include the v
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

# WARNING! This adds git, yq, and helm to the dependency list!
resource "terraform_data" "build_chart" {
  depends_on = [
    time_sleep.settle_before_rancher,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      cd ${abspath(path.root)} || true
      if [ -d chart ]; then
        rm -rf chart
      fi
      mkdir chart
      cd chart || exit 1
      ${abspath(path.module)}/build_chart.sh "${local.rancher_version}"
      cd ${abspath(path.root)} || true
      mv chart/rancher-${local.rancher_version}.tgz .
      rm -rf chart
      ls ${abspath(path.root)}/rancher-${local.rancher_version}.tgz
    EOT
  }
}

# https://github.com/rancher/rancher/blob/main/chart/values.yaml
resource "helm_release" "rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.build_chart,
  ]
  name             = "rancher"
  chart            = "${path.root}/rancher-${local.rancher_version}.tgz" #"${local.rancher_helm_repository}/${local.rancher_channel}/rancher-${local.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  force_update     = true
  timeout          = 1800 # 30m

  set {
    name  = "hostname"
    value = local.rancher_domain
  }
  set {
    name  = "replicas"
    value = "2" # this should be variable on number of nodes deployed
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
    time_sleep.settle_before_rancher,
    helm_release.rancher,
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
    random_password.password,
    time_sleep.settle_before_rancher,
    helm_release.rancher,
    time_sleep.settle_after_rancher,
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
    helm_release.rancher,
    time_sleep.settle_after_rancher,
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
    helm_release.rancher,
    time_sleep.settle_after_rancher,
    terraform_data.get_public_cert_info,
    terraform_data.get_ping,
  ]
  password = random_password.password.result
}
