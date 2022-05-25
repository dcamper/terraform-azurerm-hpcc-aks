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
  source = "github.com/Azure-Terraform/terraform-azurerm-kubernetes.git?ref=v4.2.2"

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
  timeout                    = try(local.elk.timeout, 300)
  wait_for_jobs              = try(local.elk.wait_for_jobs, false)
  lint                       = try(local.elk.lint, false)
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
  timeout                    = 300
  wait_for_jobs              = null
  lint                       = null
}

#------------------------------------------------------------------------------

resource "azurerm_network_security_group" "hpcc_nsg" {
  name                = local.hpcc_nsg_name
  location            = lower(var.azure_region)
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

# Add admin users to HPCC access if there is an explicit list of HPCC users defined
resource "azurerm_network_security_rule" "ingress_internet_admin" {
  count = length(local.hpcc_user_ip_cidr_list) > 0 ? 1 : 0

  name                        = "HPCC_Admin"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports_admin
  source_address_prefixes     = values(local.admin_cidr_map_bare)
  destination_address_prefix  = "*"
  resource_group_name         = module.resource_group.name
  network_security_group_name = resource.azurerm_network_security_group.hpcc_nsg.name
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
  resource_group_name         = module.resource_group.name
  network_security_group_name = resource.azurerm_network_security_group.hpcc_nsg.name
}

# Add public access to HPCC if there are no explicit HPCC users defined
resource "azurerm_network_security_rule" "ingress_internet_all" {
  count = length(local.hpcc_user_ip_cidr_list) == 0 ? 1 : 0

  name                        = "HPCC_Public"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports_users
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = module.resource_group.name
  network_security_group_name = resource.azurerm_network_security_group.hpcc_nsg.name
}

#------------------------------------------------------------------------------

# Set the kubectl context
resource "null_resource" "az" {
  provisioner "local-exec" {
    command     = local.az_command
    interpreter = local.is_windows_os ? ["PowerShell", "-Command"] : ["/bin/bash", "-c"]
  }

  triggers = {
    kubernetes_id = module.kubernetes.id
    build_number  = "${timestamp()}" # always trigger
  }
}
