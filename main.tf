resource "random_string" "random" {
  length  = 43
  upper   = false
  numeric = false
  special = false
}

resource "random_password" "admin" {
  length  = 6
  special = true
}

module "subscription" {
  source          = "github.com/Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = data.azurerm_subscription.current.subscription_id
}

module "naming" {
  source = "github.com/Azure-Terraform/example-naming-template.git?ref=v1.0.0"
}

module "metadata" {
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.5.2"

  naming_rules = module.naming.yaml

  market              = local.metadata.market
  location            = lower(var.azure_region)
  sre_team            = local.metadata.sre_team
  environment         = local.metadata.environment
  product_name        = local.metadata.product_name
  business_unit       = local.metadata.business_unit
  product_group       = local.metadata.product_group
  subscription_type   = local.metadata.subscription_type
  resource_group_type = local.metadata.resource_group_type
  subscription_id     = module.subscription.output.subscription_id
  project             = local.metadata.project
}

module "resource_group" {
  source = "github.com/Azure-Terraform/terraform-azurerm-resource-group.git?ref=v2.1.0"

  unique_name = false
  location    = lower(var.azure_region)
  names       = local.names
  tags        = local.tags
}

module "virtual_network" {
  source = "github.com/Azure-Terraform/terraform-azurerm-virtual-network.git?ref=v5.0.0"

  naming_rules = module.naming.yaml

  resource_group_name = module.resource_group.name
  location            = lower(var.azure_region)
  names               = local.names
  tags                = local.tags

  address_space = ["10.1.0.0/22"]

  aks_subnets = {
    hpcc = {
      private = {
        cidrs             = ["10.1.2.0/24"]
        service_endpoints = ["Microsoft.Storage"]
      }
      public = {
        cidrs             = ["10.1.3.0/24"]
        service_endpoints = ["Microsoft.Storage"]
      }
      route_table = {
        disable_bgp_route_propagation = true
        routes = {
          internet = {
            address_prefix = "0.0.0.0/0"
            next_hop_type  = "Internet"
          }
          local-vnet-10-1-0-0-21 = {
            address_prefix = "10.1.0.0/16"
            next_hop_type  = "vnetlocal"
          }
        }
      }
    }
  }
}

module "kubernetes" {
  source = "github.com/Azure-Terraform/terraform-azurerm-kubernetes.git?ref=v4.3.0"

  cluster_name        = local.aks_cluster_name
  location            = lower(var.azure_region)
  names               = local.names
  tags                = local.tags
  resource_group_name = module.resource_group.name
  identity_type       = "UserAssigned" # Allowed values: UserAssigned or SystemAssigned

  rbac = {
    enabled        = var.enable_rbac_ad
    ad_integration = var.enable_rbac_ad
  }

  network_plugin         = "azure"
  configure_network_role = true

  virtual_network = {
    subnets = {
      private = {
        id = module.virtual_network.aks.hpcc.subnets.private.id
      }
      public = {
        id = module.virtual_network.aks.hpcc.subnets.public.id
      }
    }
    route_table_id = module.virtual_network.aks.hpcc.route_table_id
  }

  default_node_pool = "system"
  node_pools = local.standard_node_pools

  api_server_authorized_ip_ranges = local.admin_cidr_map

}

#------------------------------------------------------------------------------

resource "kubernetes_secret" "sa_secret" {
  count = local.has_storage_account ? 1 : 0

  metadata {
    name      = "azure-secret"
    namespace = "default"
  }

  data = {
    azurestorageaccountname = lower(data.azurerm_storage_account.hpccsa[0].name)
    azurestorageaccountkey  = data.azurerm_storage_account.hpccsa[0].primary_access_key
  }

  type = "Opaque"
}

resource "kubernetes_secret" "premium_sa_secret" {
  count = local.has_premium_storage ? 1 : 0

  metadata {
    name      = "azure-secret-premium"
    namespace = "default"
  }

  data = {
    azurestorageaccountname = lower(data.azurerm_storage_account.hpccsa_premium[0].name)
    azurestorageaccountkey  = data.azurerm_storage_account.hpccsa_premium[0].primary_access_key
  }

  type = "Opaque"
}

#------------------------------------------------------------------------------

resource "helm_release" "hpcc" {
  depends_on = [
    module.kubernetes
  ]

  name                       = local.hpcc.name
  chart                      = "hpcc"
  repository                 = "https://hpcc-systems.github.io/helm-chart/"
  version                    = local.hpcc.version != "latest" ? local.hpcc.version : null
  create_namespace           = true
  namespace                  = try(local.hpcc.namespace, terraform.workspace)
  atomic                     = try(local.hpcc.atomic, null)
  recreate_pods              = try(local.hpcc.recreate_pods, null)
  cleanup_on_fail            = try(local.hpcc.cleanup_on_fail, null)
  disable_openapi_validation = try(local.hpcc.disable_openapi_validation, null)
  wait                       = try(local.hpcc.wait, null)
  dependency_update          = try(local.hpcc.dependency_update, null)
  timeout                    = try(local.hpcc.timeout, 600)
  wait_for_jobs              = try(local.hpcc.wait_for_jobs, null)
  lint                       = try(local.hpcc.lint, null)

  values = concat(
    local.has_storage_account ? [yamlencode(local.hpcc.storage_sa_pvc)] : [yamlencode(local.hpcc.storage_pvc)],
    try([for v in local.hpcc.values : v], []),
    [yamlencode(local.hpcc.chart_values)]
  )

  dynamic "set" {
    for_each = can(var.hpcc_image_name) ? [1] : []
    content {
      name  = "global.image.name"
      value = var.hpcc_image_name
    }
  }
}

resource "helm_release" "elk" {
  count = var.enable_elk ? 1 : 0

  name                       = local.elk.name
  namespace                  = try(local.hpcc.namespace, terraform.workspace)
  chart                      = local.elk.chart_name
  repository                 = local.elk.chart_repo
  version                    = null
  values                     = [yamlencode(local.elk.expose)]
  create_namespace           = true
  atomic                     = try(local.elk.atomic, true)
  recreate_pods              = try(local.elk.recreate_pods, false)
  cleanup_on_fail            = try(local.elk.cleanup_on_fail, false)
  disable_openapi_validation = try(local.elk.disable_openapi_validation, false)
  wait                       = try(local.elk.wait, true)
  max_history                = try(local.elk.max_historyt, 0)
  dependency_update          = try(local.elk.dependency_update, true)
  timeout                    = try(local.elk.timeout, 600)
  wait_for_jobs              = try(local.elk.wait_for_jobs, false)
  lint                       = try(local.elk.lint, false)
}

resource "helm_release" "storage" {
  count = local.has_storage_account ? 1 : 0

  name                       = "azstorage"
  chart                      = local.storage_chart
  values                     = [yamlencode(local.hpcc.storage_sa_pv)]
  create_namespace           = true
  namespace                  = try(local.hpcc.namespace, terraform.workspace)
  atomic                     = null
  recreate_pods              = null
  cleanup_on_fail            = null
  disable_openapi_validation = null
  wait                       = null
  dependency_update          = null
  timeout                    = 300
  wait_for_jobs              = null
  lint                       = null
}

#------------------------------------------------------------------------------

# When an HPCC service (ECL Watch or Roxie) is made global, AKS creates load
# balancers, public IP addresses, and network security groups within its
# MC_* self-managed resource group to allow access.  Unfortunately, the
# access that is granted is "all Internet traffic without restrictions" which
# is not that great.
#
# To complicate matters, the MC_* resource group is special.  Ordinarily, we
# should be able to ask Terraform to extract NSG resources from there but we
# apparently are locked out:  The call succeeds, but no results are returned.
#
# The following code works around those limitations to get a handle on the
# network security group, so we can then make modifications to it.  It is
# probably fragile.

# Ensure that az graph extension is installed
resource "null_resource" "az_graph" {
  provisioner "local-exec" {
    command     = "az extension add --name resource-graph"
  }
}

# Choose OS-specific script for finding Network Security Group
locals {
  wait_for_nsg_script = local.is_windows_os ? ["PowerShell", "${path.module}/helpers/wait_for_nsg.ps1"] : ["/usr/bin/env", "bash", "${path.module}/helpers/wait_for_nsg.sh"]
}

# Run a script that queries Azure for the MC_* network security group we need,
# waiting until it is actually available before returning
data "external" "k8s_mc_nsg_name" {
  depends_on = [
    resource.null_resource.az_graph,
    helm_release.hpcc # Needed because downstream code needs an HPCC service IP address
  ]

  program = concat(
    local.wait_for_nsg_script,
    ["${module.subscription.output.subscription_id}", "${module.kubernetes.node_resource_group}"]
  )
}

# Load the information from the NSG
data "azurerm_network_security_group" "k8s_nsg" {
  name                = data.external.k8s_mc_nsg_name.result["nsg"]
  resource_group_name = module.kubernetes.node_resource_group
}

# Build up the values we'll use to define new NSG rules; the
# nsg_info variable is the final result
locals {
  ecl_watch_ips = [
    for rule in data.azurerm_network_security_group.k8s_nsg.security_rule : (rule.priority == 500 ? rule.destination_address_prefix : "")
  ]
  ecl_watch_ips_1 = compact(local.ecl_watch_ips)
  ecl_watch_ip_addr = local.ecl_watch_ips_1[0]

  roxie_ips = [
    for rule in data.azurerm_network_security_group.k8s_nsg.security_rule : (rule.priority == 501 ? rule.destination_address_prefix : "")
  ]
  roxie_ips_1 = compact(local.roxie_ips)
  roxie_ip_addr = var.enable_roxie ? local.roxie_ips_1[0] : ""

  dest_ip_addrs = compact([local.ecl_watch_ip_addr, local.roxie_ip_addr])

  nsg_info = {
    network_security_group_name  = data.azurerm_network_security_group.k8s_nsg.name
    resource_group_name          = lower(data.azurerm_network_security_group.k8s_nsg.resource_group_name)
    destination_address_prefixes = local.dest_ip_addrs
  }
}

#------------------------------------------------------------------------------

# Add admin users to HPCC access if there is an explicit list of HPCC users defined
resource "azurerm_network_security_rule" "ingress_internet_admin" {
  count = length(local.admin_cidr_map_bare) > 0 ? 1 : 0

  name                        = "HPCC_Admin"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports_admin
  source_address_prefixes     = values(local.admin_cidr_map_bare)
  destination_address_prefix  = "*"
  resource_group_name         = local.nsg_info.resource_group_name
  network_security_group_name = local.nsg_info.network_security_group_name
}

# Add regular users to HPCC access if there is an explicit list of HPCC users defined
resource "azurerm_network_security_rule" "ingress_internet_users" {
  count = length(local.hpcc_user_ip_cidr_list) > 0 ? 1 : 0

  name                        = "HPCC_Users"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports_users
  source_address_prefixes     = local.hpcc_user_ip_cidr_list
  destination_address_prefix  = "*"
  resource_group_name         = local.nsg_info.resource_group_name
  network_security_group_name = local.nsg_info.network_security_group_name
}

# Deny all other users, unless the internet was granted explicit access
resource "azurerm_network_security_rule" "ingress_internet_users_deny" {
  count = contains(local.hpcc_user_ip_cidr_list, "0.0.0.0/0") ? 0 : 1

  name                        = "HPCC_Users_Deny_others"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports_users
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = local.nsg_info.resource_group_name
  network_security_group_name = local.nsg_info.network_security_group_name
}

# Deny all everyone else to admit ports
resource "azurerm_network_security_rule" "ingress_internet_admin_deny" {
  count = length(local.exposed_ports_admin_only) > 0 ? 1 : 0

  name                        = "HPCC_Admin_Deny_others"
  priority                    = 210
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports_admin_only
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = local.nsg_info.resource_group_name
  network_security_group_name = local.nsg_info.network_security_group_name
}

#------------------------------------------------------------------------------

# Set the kubectl context
resource "null_resource" "az" {
  provisioner "local-exec" {
    command     = local.az_command
    interpreter = local.is_windows_os ? ["PowerShell", "-Command"] : ["/usr/bin/env", "bash", "-c"]
  }

  triggers = {
    kubernetes_id = module.kubernetes.id
    build_number  = "${timestamp()}" # always trigger
  }
}
