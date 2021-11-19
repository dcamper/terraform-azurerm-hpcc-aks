resource "random_string" "random" {
  length  = 43
  upper   = false
  number  = false
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
  source = "github.com/Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.5.1"

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
  source = "github.com/Azure-Terraform/terraform-azurerm-resource-group.git?ref=v2.0.0"

  unique_name = false
  location    = lower(var.azure_region)
  names       = local.names
  tags        = local.tags
}

module "virtual_network" {
  source = "github.com/Azure-Terraform/terraform-azurerm-virtual-network.git?ref=v2.9.0"

  naming_rules = module.naming.yaml

  resource_group_name = module.resource_group.name
  location            = lower(var.azure_region)
  names               = local.names
  tags                = local.tags

  address_space = ["10.1.0.0/22"]

  subnets = {
    iaas-private = {
      cidrs                   = ["10.1.0.0/24"]
      route_table_association = "default"
      configure_nsg_rules     = false
      service_endpoints       = ["Microsoft.Storage"]
    }
    iaas-public = {
      cidrs                                          = ["10.1.1.0/24"]
      route_table_association                        = "default"
      configure_nsg_rules                            = false
    }
  }

  route_tables = {
    default = {
      disable_bgp_route_propagation = true
      routes = {
        internet = {
          address_prefix = "0.0.0.0/0"
          next_hop_type  = "Internet"
        }
        local-vnet = {
          address_prefix = "10.1.0.0/22"
          next_hop_type  = "vnetlocal"
        }
      }
    }
  }
}

module "kubernetes" {
  source = "github.com/Azure-Terraform/terraform-azurerm-kubernetes.git?ref=v4.2.1"

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
        id = module.virtual_network.subnets["iaas-private"].id
      }
      public = {
        id = module.virtual_network.subnets["iaas-public"].id
      }
    }
    route_table_id = module.virtual_network.route_tables["default"].id
  }

  node_pools = local.node_pools

  default_node_pool = "system" //name of the sub-key, which is the default node pool.

  api_server_authorized_ip_ranges = local.admin_cidr_map

}

resource "kubernetes_secret" "sa_secret" {
  count = local.has_storage_account ? 1 : 0

  metadata {
    name = "azure-secret"
  }

  data = local.has_storage_account ? {
    azurestorageaccountname = lower(var.storage_account_name)
    azurestorageaccountkey  = data.azurerm_storage_account.hpccsa[0].primary_access_key
  } : {}

  type = "Opaque"
}

#------------------------------------------------------------------------------

data "azurerm_storage_share" "existing_storage" {
  for_each = toset(local.has_storage_account ? local.storage_share_names : [])

  storage_account_name = var.storage_account_name
  name                 = each.key
}

#------------------------------------------------------------------------------

resource "helm_release" "hpcc" {
  depends_on = [
    module.kubernetes
  ]

  name                       = local.hpcc.name
  chart                      = "hpcc"
  repository                 = "https://hpcc-systems.github.io/helm-chart/"
  version                    = local.hpcc.version
  create_namespace           = true
  namespace                  = try(local.hpcc.namespace, terraform.workspace)
  atomic                     = try(local.hpcc.atomic, null)
  recreate_pods              = try(local.hpcc.recreate_pods, null)
  cleanup_on_fail            = try(local.hpcc.cleanup_on_fail, null)
  disable_openapi_validation = try(local.hpcc.disable_openapi_validation, null)
  wait                       = try(local.hpcc.wait, null)
  dependency_update          = try(local.hpcc.dependency_update, null)
  timeout                    = try(local.hpcc.timeout, 900)
  wait_for_jobs              = try(local.hpcc.wait_for_jobs, null)
  lint                       = try(local.hpcc.lint, null)

  values = concat(
    local.has_storage_account ? [yamlencode(local.hpcc.storage_sa2)] : [yamlencode(local.hpcc.storage_pvc)],
    try([for v in local.hpcc.values : file(v)], []),
    [yamlencode(local.hpcc.chart_values)]
  )
}

resource "helm_release" "elk" {
  count = var.enable_elk ? 1 : 0

  name                       = local.elk.name
  namespace                  = try(local.hpcc.namespace, terraform.workspace)
  chart                      = local.elk_chart
  values                     =[]
  create_namespace           = true
  atomic                     = try(local.elk.atomic, null)
  recreate_pods              = try(local.elk.recreate_pods, null)
  cleanup_on_fail            = try(local.elk.cleanup_on_fail, null)
  disable_openapi_validation = try(local.elk.disable_openapi_validation, null)
  wait                       = try(local.elk.wait, null)
  dependency_update          = try(local.elk.dependency_update, null)
  timeout                    = try(local.elk.timeout, 600)
  wait_for_jobs              = try(local.elk.wait_for_jobs, null)
  lint                       = try(local.elk.lint, null)
}

resource "helm_release" "storage" {
  count = local.has_storage_account ? 1 : 0

  name                       = "azstorage"
  chart                      = local.storage_chart
  values                     = [yamlencode(local.hpcc.storage_sa1)]
  create_namespace           = true
  namespace                  = try(local.hpcc.namespace, terraform.workspace)
  atomic                     = null
  recreate_pods              = null
  cleanup_on_fail            = null
  disable_openapi_validation = null
  wait                       = null
  dependency_update          = null
  timeout                    = 600
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

# Load the information from a particular load balancer we know was created
# in the MC_* resource group
data "azurerm_lb" "rez" {
  depends_on = [
    module.kubernetes
  ]

  name                = "kubernetes"
  resource_group_name = module.kubernetes.node_resource_group
}

# Get the backend address pool from that load balancer
data "azurerm_lb_backend_address_pool" "rez" {
  name                = "kubernetes"
  loadbalancer_id     = data.azurerm_lb.rez.id
}

# Build the name of the NSG we're interested in
locals {
  k8s_mc_unique_id = regex("virtualMachineScaleSets/aks-system-(\\d+)-vmss/", data.azurerm_lb_backend_address_pool.rez.backend_ip_configurations.0.id)
  k8s_nsg_name = format("aks-agentpool-%s-nsg", local.k8s_mc_unique_id[0])
}

# Load the information from the NSG
data "azurerm_network_security_group" "k8s_nsg" {
  depends_on = [
    module.kubernetes
  ]

  name                = local.k8s_nsg_name
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
  roxie_ip_addr = local.roxie_ips_1[0]

  dest_ip_addrs = var.enable_roxie ? [local.ecl_watch_ip_addr, local.roxie_ip_addr] : [local.ecl_watch_ip_addr]

  nsg_info = {
    network_security_group_name  = data.azurerm_network_security_group.k8s_nsg.name
    resource_group_name          = lower(data.azurerm_network_security_group.k8s_nsg.resource_group_name)
    destination_address_prefixes = local.dest_ip_addrs
  }
}

# A rule admitting HPCC admins to the cluster as users
resource "azurerm_network_security_rule" "ingress_internet_admin" {
  name                          = "HPCC_Admin"
  priority                      = 100
  direction                     = "Inbound"
  access                        = "Allow"
  protocol                      = "tcp"
  source_port_range             = "*"
  destination_port_ranges       = local.exposed_ports
  source_address_prefixes       = values(local.admin_cidr_map_bare)
  destination_address_prefixes  = local.nsg_info.destination_address_prefixes
  resource_group_name           = local.nsg_info.resource_group_name
  network_security_group_name   = local.nsg_info.network_security_group_name
}

# A rule admitting HPCC users to the cluster
resource "azurerm_network_security_rule" "ingress_internet_users" {
  count = length(local.hpcc_user_ip_cidr_list) > 0 ? 1 : 0

  name                          = "HPCC_Users"
  priority                      = 110
  direction                     = "Inbound"
  access                        = "Allow"
  protocol                      = "tcp"
  source_port_range             = "*"
  destination_port_ranges       = local.exposed_ports
  source_address_prefixes       = local.hpcc_user_ip_cidr_list
  destination_address_prefixes  = local.nsg_info.destination_address_prefixes
  resource_group_name           = local.nsg_info.resource_group_name
  network_security_group_name   = local.nsg_info.network_security_group_name
}

# Catch-all rule that denies access from the internet; note that this
# rule precedes the one supplied by AKS that grants everyone access, which
# has a priority of 500, so this one will trump the AKS-supplied rule
resource "azurerm_network_security_rule" "deny_other_internet" {
  name                          = "Deny_Other_Internet"
  priority                      = 400
  direction                     = "Inbound"
  access                        = "Deny"
  protocol                      = "tcp"
  source_port_range             = "*"
  destination_port_ranges       = local.exposed_ports
  source_address_prefix         = "Internet"
  destination_address_prefixes  = local.nsg_info.destination_address_prefixes
  resource_group_name           = local.nsg_info.resource_group_name
  network_security_group_name   = local.nsg_info.network_security_group_name
}

#------------------------------------------------------------------------------

resource "null_resource" "az" {
  count = var.auto_connect ? 1 : 0

  provisioner "local-exec" {
    command     = local.az_command
    interpreter = local.is_windows_os ? ["PowerShell", "-Command"] : ["/bin/bash", "-c"]
  }

  triggers = {
    kubernetes_id = module.kubernetes.id
    build_number  = "${timestamp()}" # always trigger
  }
}
