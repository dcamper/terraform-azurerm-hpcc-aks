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
  location            = var.azure_region
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
  location    = var.azure_region
  names       = local.names
  tags        = local.tags
}

module "virtual_network" {
  source = "github.com/Azure-Terraform/terraform-azurerm-virtual-network.git?ref=v2.9.0"

  naming_rules = module.naming.yaml

  resource_group_name = module.resource_group.name
  location            = var.azure_region
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
      enforce_private_link_endpoint_network_policies = true
      enforce_private_link_service_network_policies  = true
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
  location            = var.azure_region
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

  api_server_authorized_ip_ranges = local.access_map_cidr

}

resource "kubernetes_secret" "sa_secret" {
  count = local.has_storage_account ? 1 : 0

  metadata {
    name = "azure-secret"
  }

  data = local.has_storage_account ? {
    azurestorageaccountname = var.storage_account_name
    azurestorageaccountkey  = data.azurerm_storage_account.hpccsa[0].primary_access_key
  } : {}

  type = "Opaque"
}

resource "helm_release" "hpcc" {
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
    local.has_storage_account ? [file("${path.root}/customizations/storage-sa2.yaml")] : [file("${path.root}/customizations/storage-pvc.yaml")],
    try([for v in local.hpcc.values : file(v)], []),
    [yamlencode(local.hpcc.chart_values)]
  )

  depends_on = [helm_release.storage, module.kubernetes]
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
  values                     = [file("${path.root}/customizations/storage-sa1.yaml")]
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

resource "azurerm_network_security_rule" "ingress_internet_admin" {
  name                        = "HPCC_Admin"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports
  source_address_prefixes     = values(local.access_map_bare)
  destination_address_prefix  = "*"
  resource_group_name         = module.virtual_network.subnets["iaas-public"].resource_group_name
  network_security_group_name = module.virtual_network.subnets["iaas-public"].network_security_group_name
}

resource "azurerm_network_security_rule" "ingress_internet_users" {
  count = length(local.hpcc_user_ip_cidr_list) > 0 ? 1 : 0
  name                        = "HPCC_Users"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "tcp"
  source_port_range           = "*"
  destination_port_ranges     = local.exposed_ports
  source_address_prefixes     = local.hpcc_user_ip_cidr_list
  destination_address_prefix  = "*"
  resource_group_name         = module.virtual_network.subnets["iaas-public"].resource_group_name
  network_security_group_name = module.virtual_network.subnets["iaas-public"].network_security_group_name
}

resource "null_resource" "az" {
  count = var.auto_connect ? 1 : 0

  provisioner "local-exec" {
    command     = local.az_command
    interpreter = local.is_windows_os ? ["PowerShell", "-Command"] : ["/bin/bash", "-c"]
  }

  triggers = { kubernetes_id = module.kubernetes.id } //must be run after the Kubernetes cluster is deployed.
}
