locals {
  names = var.disable_naming_conventions ? merge(
    {
      business_unit     = var.metadata.business_unit
      environment       = var.metadata.environment
      location          = var.resource_group.location
      market            = var.metadata.market
      subscription_type = var.metadata.subscription_type
    },
    var.metadata.product_group != "" ? { product_group = var.metadata.product_group } : {},
    var.metadata.product_name != "" ? { product_name = var.metadata.product_name } : {},
    var.metadata.resource_group_type != "" ? { resource_group_type = var.metadata.resource_group_type } : {}
  ) : module.metadata.names

  enforced_tags = {
    "admin" = var.admin.name
    "email" = var.admin.email
    "owner" = var.admin.email
    "owner_email" = var.admin.email
  }
  tags = var.disable_naming_conventions ? merge(var.tags, local.enforced_tags) : merge(module.metadata.tags, local.enforced_tags, try(var.tags))

  cluster_name = "${local.names.resource_group_type}-${local.names.product_name}-terraform-${local.names.location}-${var.admin.name}-${terraform.workspace}"

  hpcc_repository    = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/hpcc-${var.hpcc.version}.tgz"
  storage_repository = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/hpcc-azurefile-0.1.0.tgz"
  elk_repository     = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/elastic4hpcclogs-1.0.0.tgz"

  hpcc_chart    = can(var.hpcc.chart) ? var.hpcc.chart : local.hpcc_repository
  storage_chart = can(var.storage.chart) ? var.storage.chart : local.storage_repository
  elk_chart     = can(var.elk.chart) ? var.elk.chart : local.elk_repository

  az_command = try("az aks get-credentials --name ${module.kubernetes.name} --resource-group ${module.resource_group.name} --overwrite", "")

  is_windows_os = substr(pathexpand("~"), 0, 1) == "/" ? false : true

  host_ip_cidr    = "${chomp(data.http.host_ip.body)}/32"
  # Each value can have any kind of CIDR range
  access_map_cidr = merge(var.api_server_authorized_ip_ranges, { "host_ip" = local.host_ip_cidr })
  # Remove /31 and /32 CIDR ranges (some TF modules don't like them)
  access_map_bare = zipmap(
                            keys(local.access_map_cidr),
                            [for s in values(local.access_map_cidr) : replace(s, "/\\/3[12]$/", "")]
                          )
}
