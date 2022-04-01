data "azurerm_advisor_recommendations" "advisor" {

  filter_by_category        = ["Security", "Cost"]

  filter_by_resource_groups = concat(
    [module.resource_group.name],
    local.has_storage_account ? [var.storage_account_resource_group_name] : []
  )
}

data "http" "host_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "azurerm_subscription" "current" {
}

data "azurerm_storage_account" "hpccsa" {
  count = local.has_storage_account ? 1 : 0
  name                = local.has_storage_account ? var.storage_account_name : "placeholder"
  resource_group_name = local.has_storage_account ? var.storage_account_resource_group_name : "placeholder"
}
