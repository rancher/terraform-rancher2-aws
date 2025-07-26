
locals {
  rancher_domain            = var.project_domain
  rancher_helm_repo         = var.rancher_helm_repo
  rancher_helm_channel      = var.rancher_helm_channel
  rancher_version           = replace(var.rancher_version, "v", "") # don't include the v
  helm_chart_use_strategy   = var.rancher_helm_chart_use_strategy
  rancher_helm_chart_values = jsondecode(base64decode(var.rancher_helm_chart_values))
  default_hc_values = {
    "hostname"                                            = local.rancher_domain
    "replicas"                                            = "3"
    "bootstrapPassword"                                   = "admin"
    "ingress.enabled"                                     = "true"
    "ingress.tls.source"                                  = "letsEncrypt"
    "tls"                                                 = "ingress"
    "letsEncrypt.ingress.class"                           = "nginx"
    "letsEncrypt.environment"                             = "production"
    "letsEncrypt.email"                                   = local.email
    "certmanager.version"                                 = local.cert_manager_version
    "agentTLSMode"                                        = "strict"
    "privateCA"                                           = "true"
    "additionalTrustedCAs"                                = "true"
    "ingress.extraAnnotations.cert-manager\\.io\\/issuer" = "rancher"
  }
  helm_chart_values = coalesce( # using coalesce like this essentially gives us a switch function
    (local.helm_chart_use_strategy == "merge" ? merge(local.default_hc_values, local.rancher_helm_chart_values) : null),
    (local.helm_chart_use_strategy == "default" ? local.default_hc_values : null),
    (local.helm_chart_use_strategy == "provide" ? local.rancher_helm_chart_values : null),
  ) # WARNING! Some config is necessary, if the result is an empty string the coalesce will fail
  zone_id              = var.zone_id
  region               = var.region
  email                = var.email
  cert_manager_version = replace(var.cert_manager_version, "v", "") # don't include the v
  acme_server          = var.acme_server_url
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

resource "kubernetes_manifest" "issuer" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
  ]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = "rancher"
      namespace = "cattle-system"
      annotations = {
        "app.kubernetes.io/managed-by"   = "Helm"
        "meta.helm.sh/release-name"      = "rancher"
        "meta.helm.sh/release-namespace" = "cattle-system"
      }
      labels = {
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    spec = {
      acme = {
        email  = local.email
        server = local.acme_server # "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "acme-account-key"
        }
        solvers = [
          # https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEChallengeSolver
          {
            # https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEIssuerDNS01ProviderRoute53
            # https://cert-manager.io/docs/configuration/acme/dns01/route53/#ambient-credentials
            # https://docs.aws.amazon.com/sdkref/latest/guide/environment-variables.html
            dns01 = {
              route53 = {
                ambient      = true
                region       = local.region
                hostedZoneID = local.zone_id
              }
            }
          }
        ]
      }
    }
  }
}

# https://github.com/rancher/rancher/blob/main/chart/values.yaml
resource "helm_release" "rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_manifest.issuer,
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
    for_each = local.helm_chart_values
    content {
      name  = set.key
      type  = "string"
      value = set.value
    }
  }
}

# The Helm resource completes in less than 10 seconds
#   at which time the tls-rancher-ingress secret is generated
data "kubernetes_secret_v1" "certificate" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_manifest.issuer,
    helm_release.rancher,
  ]
  metadata {
    name      = "tls-rancher-ingress"
    namespace = "cattle-system"
  }
}

# we need to create the tls-ca and tls-ca-additional secrets while the rancher pod is starting up
# the rancher pod will fail a few times, but once the secrets are in place it will start and everything will start to work
resource "kubernetes_secret" "rancher_tls_ca" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    data.kubernetes_secret_v1.certificate,
  ]
  metadata {
    name      = "tls-ca"
    namespace = "cattle-system"
  }
  type = "generic"
  data = {
    "cacerts.pem" = data.kubernetes_secret_v1.certificate.data["tls.crt"], # don't base64 encode
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
    kubernetes_manifest.issuer,
    helm_release.rancher,
    data.kubernetes_secret_v1.certificate,
  ]
  metadata {
    name      = "tls-ca-additional"
    namespace = "cattle-system"
  }
  type = "generic"
  data = {
    "ca-additional.pem" = data.kubernetes_secret_v1.certificate.data["tls.crt"], # don't base64 encode
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}

resource "terraform_data" "wait_for_rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    data.kubernetes_secret_v1.certificate,
    kubernetes_secret.rancher_tls_ca,
    kubernetes_secret.rancher_tls_ca_additional,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      cd ${abspath(path.root)} || true
      chmod +x ${abspath(path.module)}/runningPods.sh
      echo "using kubeconfig located at $KUBECONFIG"
      ${abspath(path.module)}/runningPods.sh
      ${abspath(path.module)}/runningDeployments.sh
    EOT
  }
}

resource "terraform_data" "get_public_cert_info" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    data.kubernetes_secret_v1.certificate,
    kubernetes_secret.rancher_tls_ca,
    kubernetes_secret.rancher_tls_ca_additional,
    terraform_data.wait_for_rancher,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      MAX=4
      ATTEMPTS=0
      E=""
      INTERVAL=30 # seconds
      while [ $ATTEMPTS -lt $MAX ]; do
        CERT="$(echo | openssl s_client -showcerts -servername ${local.rancher_domain} -connect ${local.rancher_domain}:443 2>/dev/null | openssl x509 -inform pem -noout -text)"
        echo "$CERT"
        FAKE="$(echo "$CERT" | grep 'Kubernetes Ingress Controller Fake Certificate')"
        if [ -z "$FAKE" ]; then
          echo "verified certificate is not fake"
          ATTEMPTS=$MAX
          E=""
        else
          ATTEMPTS=$((ATTEMPTS+1))
          SLEEPTIME=$((INTERVAL*ATTEMPTS))
          echo "certificate is fake! retrying in $SLEEPTIME seconds..."
          sleep $SLEEPTIME
          E="certificate is fake"
        fi;
      done
      if [ -z "$E" ]; then
        exit 0
      else
        echo "$E"
        timeout 3600 kubectl get order -A
        timeout 3600 kubectl get challenge -A
        timeout 3600 kubectl get CertificateRequest -A
        timeout 3600 kubectl get Certificate -A
        timeout 3600 kubectl describe order -n cattle-system
        timeout 3600 kubectl describe challenge -n cattle-system
        exit 1
      fi
    EOT
  }
}

provider "rancher2" {
  api_url   = "https://${local.rancher_domain}"
  bootstrap = true
  ca_certs  = data.kubernetes_secret_v1.certificate.data["tls.crt"]
  alias     = "bootstrap"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!-_=+"
}

resource "rancher2_bootstrap" "admin" {
  depends_on = [
    time_sleep.settle_before_rancher,
    terraform_data.wait_for_nginx,
    terraform_data.cattle-system,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    terraform_data.wait_for_rancher,
    terraform_data.get_public_cert_info,
    data.kubernetes_secret_v1.certificate,
    kubernetes_secret.rancher_tls_ca,
    kubernetes_secret.rancher_tls_ca_additional,
  ]
  provider = rancher2.bootstrap
  password = random_password.password.result
}
