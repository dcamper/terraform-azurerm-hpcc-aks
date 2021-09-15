locals {
  metadata = {
    project             = "hpcc_k8s"
    product_name        = var.product_name
    business_unit       = "infra"
    environment         = "sandbox"
    market              = "us"
    product_group       = "solutionslab"
    resource_group_type = "app"
    sre_team            = "solutionslab"
    subscription_type   = "dev"
  }

  names = module.metadata.names

  enforced_tags = {
    "admin" = var.admin_name
    "email" = var.admin_email
    "owner" = var.admin_name
    "owner_email" = var.admin_email
  }
  tags = merge(module.metadata.tags, try(var.extra_tags, local.enforced_tags))

  aks_cluster_name = "${local.names.resource_group_type}-${local.names.product_name}-terraform-${local.names.location}-${var.admin_username}-${terraform.workspace}"

  node_pools = {
    system = {
      vm_size             = "Standard_B2s"
      node_count          = 1
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 2
    }

    addpool1 = {
      vm_size             = var.node_size
      enable_auto_scaling = true
      min_count           = 1
      max_count           = var.max_node_count
    }
  }

  has_storage_account = try(var.storage_account_name, "") != "" && try(var.storage_account_resource_group_name, "") != ""

  hpcc_chart    = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/hpcc-${var.hpcc_version}.tgz"
  storage_chart = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/hpcc-azurefile-0.1.0.tgz"
  elk_chart     = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/elastic4hpcclogs-1.0.0.tgz"

  hpcc = {
    version        = var.hpcc_version
    namespace      = "default"
    name           = "${local.metadata.product_name}-hpcc"

    values         = [
      var.enable_roxie ? "./customizations/esp-roxie.yaml" : "./customizations/esp.yaml",
      "./customizations/eclcc.yaml",
      "./customizations/thor.yaml",
      "./customizations/hthor.yaml",
      var.enable_roxie ? "./customizations/roxie-on.yaml" : "./customizations/roxie-off.yaml",
      "./customizations/security.yaml"
    ]

    ecl_watch_port = 8010
    roxie_port     = 8002
    elk_port       = 5601
  }

  elk = {
    name   = "${local.metadata.product_name}-elk"
  }

  default_admin_ip_cidr_maps = {
    "alpharetta" = "66.241.32.0/19"
    "boca"       = "209.243.48.0/20"
  }

  host_ip_cidr    = "${chomp(data.http.host_ip.body)}/32"
  # Each value can have any kind of CIDR range
  access_map_cidr = merge(local.default_admin_ip_cidr_maps, try(var.admin_ip_cidr_map), { "host_ip" = local.host_ip_cidr })
  # Remove /31 and /32 CIDR ranges (some TF modules don't like them)
  access_map_bare = zipmap(
    keys(local.access_map_cidr),
    [for s in values(local.access_map_cidr) : replace(s, "/\\/3[12]$/", "")]
  )
  # Rewrite HPCC user access CIDR addresses, removing /31 and /32
  hpcc_user_ip_cidr_list = [for s in var.hpcc_user_ip_cidr_list : replace(s, "/\\/3[12]$/", "")]

  exposed_ports = concat(
    [tostring(local.hpcc.ecl_watch_port)],
    var.enable_elk ? [tostring(local.hpcc.elk_port)] : [],
    var.enable_roxie ? [tostring(local.hpcc.roxie_port)] : []
  )

  is_windows_os = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  az_command = try("az aks get-credentials --name ${module.kubernetes.name} --resource-group ${module.resource_group.name} --overwrite", "")
}
