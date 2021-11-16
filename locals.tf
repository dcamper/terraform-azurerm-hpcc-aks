locals {
  metadata = {
    project             = "hpcc_k8s"
    product_name        = lower(var.product_name)
    business_unit       = "infra"
    environment         = "sandbox"
    market              = "us"
    product_group       = "solutionslab"
    resource_group_type = "app"
    sre_team            = "solutionslab"
    subscription_type   = "dev"
  }

  names = module.metadata.names

  #----------------------------------------------------------------------------

  enforced_tags = {
    "admin" = var.admin_name
    "email" = lower(var.admin_email)
    "owner" = var.admin_name
    "owner_email" = lower(var.admin_email)
  }
  tags = merge(module.metadata.tags, local.enforced_tags, try(var.extra_tags, {}))

  #----------------------------------------------------------------------------

  aks_cluster_name = lower("${local.names.resource_group_type}-${local.names.product_name}-terraform-${local.names.location}-${var.admin_username}-${terraform.workspace}")

  #----------------------------------------------------------------------------

  node_pools = {
    system = {
      vm_size             = "Standard_B2s"
      node_count          = 1
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 2
    }

    hpcc = {
      vm_size             = var.node_size
      node_labels         = {"group": "hpcc"}
      enable_auto_scaling = true
      min_count           = 1
      max_count           = var.max_node_count
    }
  }

  #----------------------------------------------------------------------------

  has_storage_account = try(var.storage_account_name, "") != "" && try(var.storage_account_resource_group_name, "") != ""
  
  storage_share_names = [
    "dalishare",
    "dllsshare",
    "sashashare",
    "datashare",
    "lzshare"
  ]

  storage_size = {
      "dalishare"   = local.has_storage_account ? format("%dGi", data.azurerm_storage_share.existing_storage["dalishare"].quota) : "10Gi"
      "dllsshare"   = local.has_storage_account ? format("%dGi", data.azurerm_storage_share.existing_storage["dllsshare"].quota) : "4Gi"
      "sashashare"  = local.has_storage_account ? format("%dGi", data.azurerm_storage_share.existing_storage["sashashare"].quota) : "2Gi"
      "datashare"   = local.has_storage_account ? format("%dGi", data.azurerm_storage_share.existing_storage["datashare"].quota) : "${var.storage_data_gb}Gi"
      "lzshare"     = local.has_storage_account ? format("%dGi", data.azurerm_storage_share.existing_storage["lzshare"].quota) : "${var.storage_lz_gb}Gi"
  }

  #----------------------------------------------------------------------------

  hpcc_chart    = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/hpcc-${var.hpcc_version}.tgz"
  storage_chart = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/hpcc-azurefile-0.1.0.tgz"
  elk_chart     = "https://github.com/hpcc-systems/helm-chart/raw/master/docs/elastic4hpcclogs-1.0.0.tgz"

  #----------------------------------------------------------------------------

  hpcc = {
    version        = var.hpcc_version
    namespace      = "default"
    name           = "${local.metadata.product_name}-hpcc"

    values         = concat(
      ["./customizations/placements.yaml"],
      [var.enable_roxie ? "./customizations/esp-roxie.yaml" : "./customizations/esp.yaml"],
      ["./customizations/eclcc.yaml"],
      ["./customizations/thor.yaml"],
      ["./customizations/hthor.yaml"],
      [var.enable_roxie ? "./customizations/roxie-on.yaml" : "./customizations/roxie-off.yaml"],
      var.enable_code_security ? ["./customizations/security.yaml"] : []
    )

    ecl_watch_port = 8010
    roxie_port     = 8002
    elk_port       = 5601

    chart_values = {
      thor = [
        {
          name       = "thor"
          prefix     = "thor"
          numWorkers = var.thor_num_workers
          maxJobs    = var.thor_max_jobs
          maxGraphs  = 2
        }
      ]
    }

    storage_pvc = {
      storage = {
        planes = [
          {
            name         = "dali"
            storageSize  = local.storage_size["dalishare"]
            storageClass = "azurefile"
            prefix       = "/var/lib/HPCCSystems/dalistorage"
            category     = "dali"
          },
          {
            name         = "dll"
            storageSize  = local.storage_size["dllsshare"]
            storageClass = "azurefile"
            prefix       = "/var/lib/HPCCSystems/queries"
            category     = "dll"
          },
          {
            name         = "sasha"
            storageSize  = local.storage_size["sashashare"]
            storageClass = "azurefile"
            prefix       = "/var/lib/HPCCSystems/sashastorage"
            category     = "sasha"
          },
          {
            name         = "data"
            storageSize  = local.storage_size["datashare"]
            storageClass = "azurefile"
            prefix       = "/var/lib/HPCCSystems/hpcc-data"
            category     = "data"
          },
          {
            name         = "mydropzone"
            storageSize  = local.storage_size["lzshare"]
            storageClass = "azurefile"
            prefix       = "/var/lib/HPCCSystems/mydropzone"
            category     = "lz"
          }
        ]
      },
      sasha = {
        wu-archiver = {
          plane = "sasha"
        },
        dfuwu-archiver = {
          plane = "sasha"
        }
      }
    }

    storage_sa1 = {
      common = {
        mountPrefix     = "/var/lib/HPCCSystems"
        secretName      = "azure-secret"
        secretNamespace = "default"
      },
      planes = [
        {
          name      = "dali"
          subPath   = "dalistorage"
          size      = local.storage_size["dalishare"]
          category  = "dali"
          sku       = "Standard_LRS"
          shareName = "dalishare"
        },
        {
          name      = "dll"
          subPath   = "queries"
          size      = local.storage_size["dllsshare"]
          category  = "dll"
          rwmany    = true
          sku       = "Standard_LRS"
          shareName = "dllsshare"
        },
        {
          name      = "sasha"
          subPath   = "sasha"
          size      = local.storage_size["sashashare"]
          rwmany    = true
          category  = "sasha"
          sku       = "Standard_LRS"
          shareName = "sashashare"
        },
        {
          name      = "data"
          subPath   = "hpcc-data"
          size      = local.storage_size["datashare"]
          category  = "data"
          rwmany    = true
          sku       = "Standard_LRS"
          shareName = "datashare"
        },
        {
          name      = "mydropzone"
          subPath   = "dropzone"
          size      = local.storage_size["lzshare"]
          rwmany    = true
          category  = "lz"
          sku       = "Standard_LRS"
          shareName = "lzshare"
        }
      ]
    }

    storage_sa2 = {
      storage = {
        planes = [
          {
            name         = "dali"
            pvc          = "dali-azstorage-hpcc-azurefile-pvc"
            prefix       = "/var/lib/HPCCSystems/dalistorage"
            category     = "dali"
          },
          {
            name         = "dll"
            pvc          = "dll-azstorage-hpcc-azurefile-pvc"
            prefix       = "/var/lib/HPCCSystems/queries"
            category     = "dll"
          },
          {
            name         = "sasha"
            pvc          = "sasha-azstorage-hpcc-azurefile-pvc"
            prefix       = "/var/lib/HPCCSystems/sashastorage"
            category     = "sasha"
          },
          {
            name         = "data"
            pvc          = "data-azstorage-hpcc-azurefile-pvc"
            prefix       = "/var/lib/HPCCSystems/hpcc-data"
            category     = "data"
          },
          {
            name         = "mydropzone"
            pvc          = "mydropzone-azstorage-hpcc-azurefile-pvc"
            prefix       = "/var/lib/HPCCSystems/mydropzone"
            category     = "lz"
          }
        ]
      },
      sasha = {
        wu-archiver = {
          plane = "sasha"
        },
        dfuwu-archiver = {
          plane = "sasha"
        }
      }
    }
  }

  #----------------------------------------------------------------------------

  elk = {
    name   = "${local.metadata.product_name}-elk"
  }

  #----------------------------------------------------------------------------

  # Corporate networks to automatically include in AKS admin and HPCC user access
  default_admin_ip_cidr_maps = {
    "alpharetta" = "66.241.32.0/19"
    "boca"       = "209.243.48.0/20"
  }

  # CIDR address of user running Terraform
  host_ip         = "${chomp(data.http.host_ip.body)}"
  host_ip_cidr    = "${local.host_ip}/32"

  # Check to see if user's IP address is in a default admin CIDR
  admin_overlap_test = [
    for s in values(local.default_admin_ip_cidr_maps)
      : cidrsubnet("${local.host_ip}/${regex("/(\\d{1,2})$", s)[0]}", 0, 0) == s
  ]
  admin_overlaps = anytrue(local.admin_overlap_test)

  # List of all CIDR addresses that can admin AKS
  admin_cidr_map = merge(
    local.default_admin_ip_cidr_maps,
    try(var.admin_ip_cidr_map, {}),
    local.admin_overlaps ? {} : { "host_ip" = local.host_ip_cidr }
  )

  # Remove /31 and /32 CIDR suffixes from AKS admin list (some TF modules don't like them)
  admin_cidr_map_bare = zipmap(
    keys(local.admin_cidr_map),
    [for s in values(local.admin_cidr_map) : replace(s, "/\\/3[12]$/", "")]
  )

  # Remove /31 and /32 CIDR suffixes from HPCC user access list
  hpcc_user_ip_cidr_list = [for s in var.hpcc_user_ip_cidr_list : replace(s, "/\\/3[12]$/", "")]

  #----------------------------------------------------------------------------

  exposed_ports = concat(
    [tostring(local.hpcc.ecl_watch_port)],
    var.enable_elk ? [tostring(local.hpcc.elk_port)] : [],
    var.enable_roxie ? [tostring(local.hpcc.roxie_port)] : []
  )

  #----------------------------------------------------------------------------

  is_windows_os = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  az_command = try("az aks get-credentials --name ${module.kubernetes.name} --resource-group ${module.resource_group.name} --overwrite --admin", "")
}
