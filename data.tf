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

#------------------------------------------------------------------------------

data "azurerm_storage_account" "hpccsa" {
  count = local.has_storage_account ? 1 : 0
  name                = var.storage_account_name
  resource_group_name = var.storage_account_resource_group_name
}

data "azurerm_storage_account" "hpccsa_premium" {
  count = local.has_premium_storage ? 1 : 0
  name                = "${var.storage_account_name}premium"
  resource_group_name = var.storage_account_resource_group_name
}

#------------------------------------------------------------------------------

data "azurerm_storage_share" "existing_storage" {
  for_each = toset(local.has_storage_account ? local.storage_share_names : [])

  storage_account_name = data.azurerm_storage_account.hpccsa[0].name
  name                 = each.key
}

data "azurerm_storage_share" "existing_storage_premium" {
  for_each = toset(local.has_premium_storage ? local.premium_storage_share_names : [])

  storage_account_name = data.azurerm_storage_account.hpccsa_premium[0].name
  name                 = each.key
}
