locals {
  # project
  identifier   = var.identifier
  owner        = var.owner
  project_name = var.project_name
  domain       = lower(var.domain)
  zone         = lower(var.zone)
  fqdn         = lower(join(".", [local.domain, local.zone]))
  # access
  key_name = var.key_name
  key      = var.key
  username = var.username
  admin_ip = var.admin_ip
  # rke2
  rke2_version = var.rke2_version
  local_file_path = (
    var.local_file_path != "" ?
    (var.local_file_path == path.root ? "${path.root}/rke2" : var.local_file_path) :
    "${path.root}/rke2"
  )
  install_method     = var.install_method
  cni                = var.cni
  node_configuration = var.node_configuration
  # rancher
  install_cert_manager       = true # only used to isolate Rancher install in testing
  cert_manager_version       = var.cert_manager_version
  cert_use_strategy          = var.cert_use_strategy # "module", "rancher", "supply"
  skip_cert                  = contains(["rancher", "supply"], local.cert_use_strategy)
  externalTLS                = contains(["module", "supply"], local.cert_use_strategy)
  configure_cert_manager     = (local.externalTLS ? false : true) # opposite of externalTLS
  cert_manager_configuration = var.cert_manager_configuration
  cert_manager_config = (local.cert_manager_configuration == null ? {
    aws_access_key_id     = ""
    aws_secret_access_key = ""
    aws_region            = ""
    aws_session_token     = ""
    acme_email            = ""
    acme_server_url       = ""
  } : local.cert_manager_configuration)
  tls_public_cert  = var.tls_public_cert
  tls_public_chain = var.tls_public_chain
  tls_private_key  = var.tls_private_key
  cert_public = coalesce(
    (local.cert_use_strategy == "module" ? module.cluster.cert.public_key : null),
    (local.cert_use_strategy == "supply" ? local.tls_public_cert : null),
    (local.cert_use_strategy == "rancher" ? "empty" : null),
  )
  cert_private = coalesce(
    (local.cert_use_strategy == "module" ? module.cluster.cert.private_key : null),
    (local.cert_use_strategy == "supply" ? local.tls_private_key : null),
    (local.cert_use_strategy == "rancher" ? "empty" : null),
  )
  cert_chain = coalesce(
    (local.cert_use_strategy == "module" ? module.cluster.cert.chain : null),
    (local.cert_use_strategy == "supply" ? local.tls_public_chain : null),
    (local.cert_use_strategy == "rancher" ? "empty" : null),
  )
  rancher_version                 = var.rancher_version
  rancher_helm_repo               = var.rancher_helm_repo
  rancher_helm_channel            = var.rancher_helm_channel
  ip_family                       = "ipv4"
  rancher_helm_chart_values       = var.rancher_helm_chart_values
  rancher_helm_chart_use_strategy = var.rancher_helm_chart_use_strategy
  install_rancher                 = var.install_rancher
  bootstrap_rancher               = var.bootstrap_rancher
  acme_server_url                 = var.acme_server_url
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition = can(regex(
        "^(?:https?://)?[[:alpha:]](?:[[:alnum:]\\p{Pd}]{1,63}\\.)+[[:alnum:]\\p{Pd}]{1,62}[[:alnum:]](?::[[:digit:]]{1,5})?$",
        local.fqdn
      ))
      error_message = "The fqdn must be a fully qualified domain name"
    }
    precondition {
      condition     = local.fqdn == lower(local.fqdn)
      error_message = "fqdn must be lowercase"
    }
    precondition {
      condition = (
        local.rancher_helm_chart_values != {} &&
        lookup(local.rancher_helm_chart_values, "hostname", "") != "" &&
        lookup(local.rancher_helm_chart_values, "hostname", "") != lower(lookup(local.rancher_helm_chart_values, "hostname", ""))
      ) ? false : true # define the bad condition and flip the boolean to trigger the error
      error_message = "hostname in rancher_helm_chart_values must be lowercase"
    }
    precondition {
      condition     = local.cert_use_strategy != "rancher" || local.cert_manager_configuration != null
      error_message = "cert_manager_configuration must not be null when using rancher for certs"
    }
    precondition {
      condition     = local.cert_use_strategy != "supply" || (local.tls_public_cert != null && local.tls_public_cert != "")
      error_message = "tls_public_cert must not be null or empty when using supply strategy for certs"
    }
    precondition {
      condition     = local.cert_use_strategy != "supply" || (local.tls_private_key != null && local.tls_private_key != "")
      error_message = "tls_private_key must not be null or empty when using supply strategy for certs"
    }
  }
}

data "aws_route53_zone" "zone" {
  name = "${local.zone}."
}

module "cluster" {
  depends_on = [
    terraform_data.input_validation,
  ]
  source             = "./modules/cluster"
  identifier         = local.identifier
  owner              = local.owner
  project_name       = local.project_name
  domain             = local.domain
  zone               = local.zone
  key_name           = local.key_name
  key                = local.key
  username           = local.username
  runner_ip          = local.admin_ip
  rke2_version       = local.rke2_version
  file_path          = local.local_file_path
  install_method     = local.install_method
  cni                = local.cni
  node_configuration = local.node_configuration
  ip_family          = local.ip_family
  acme_server_url    = local.acme_server_url
  skip_cert_creation = local.skip_cert
}

module "install_cert_manager" {
  depends_on = [
    terraform_data.input_validation,
    module.cluster,
  ]
  count                      = (local.install_cert_manager ? 1 : 0)
  source                     = "./modules/install_cert_manager"
  path                       = local.local_file_path
  project_domain             = local.fqdn
  zone                       = local.zone
  zone_id                    = data.aws_route53_zone.zone.zone_id
  configure_cert_manager     = local.configure_cert_manager
  cert_manager_version       = local.cert_manager_version
  cert_manager_configuration = local.cert_manager_config
}

module "install_rancher" {
  depends_on = [
    terraform_data.input_validation,
    module.cluster,
    module.install_cert_manager,
  ]
  count                           = (local.install_rancher ? 1 : 0)
  source                          = "./modules/install_rancher"
  path                            = local.local_file_path
  project_domain                  = local.fqdn
  zone_id                         = data.aws_route53_zone.zone.zone_id
  region                          = local.cert_manager_config.aws_region
  email                           = local.cert_manager_config.acme_email
  acme_server_url                 = local.acme_server_url
  rancher_version                 = local.rancher_version
  rke2_version                    = local.rke2_version
  rancher_helm_repo               = local.rancher_helm_repo
  rancher_helm_channel            = local.rancher_helm_channel
  cert_manager_version            = local.cert_manager_version
  externalTLS                     = local.externalTLS
  cert_public                     = local.cert_public
  cert_private                    = local.cert_private
  cert_chain                      = local.cert_chain
  rancher_helm_chart_values       = local.rancher_helm_chart_values
  rancher_helm_chart_use_strategy = local.rancher_helm_chart_use_strategy
}

module "bootstrap_rancher" {
  depends_on = [
    terraform_data.input_validation,
    module.cluster,
    module.install_cert_manager,
    module.install_rancher,
  ]
  count          = (local.bootstrap_rancher ? 1 : 0)
  source         = "./modules/bootstrap_rancher"
  path           = local.local_file_path
  rancher_domain = local.fqdn
  ca_certs       = module.install_rancher[0].ca_certs
  admin_password = module.install_rancher[0].rancher_admin_password
}
