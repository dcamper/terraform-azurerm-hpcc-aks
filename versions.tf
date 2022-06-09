terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0" // Version 3.x breaks stuff; see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/3.0-upgrade-guide
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.3.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.1.2"
    }
  }
  required_version = ">=0.15.0"
}
