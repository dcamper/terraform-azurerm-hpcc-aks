###############################################################################
# Prompted variables (user will be asked to supply them at plan/apply time)
###############################################################################

variable "admin_email" {
  type        = string
  description = "REQUIRED.  Email address of the administrator of this HPCC Systems cluster.\nExample entry: jane.doe@hpccsystems.com"
  validation {
    condition     = length(regexall("^[^@]+@[^@]+$", var.admin_email)) > 0
    error_message = "Value must at least look like a valid email address."
  }
}

variable "admin_username" {
  type        = string
  description = "REQUIRED.  Username of the administrator of this HPCC Systems cluster.\nExample entry: jdoe"
  validation {
    condition     = length(var.admin_username) > 1 && length(regexall(" ", var.admin_username)) == 0
    error_message = "Value must at least two characters in length and contain no spaces."
  }
}

variable "admin_name" {
  type        = string
  description = "REQUIRED.  Name of the administrator of this HPCC Systems cluster.\nExample entry: Jane Doe"
}

variable "product_name" {
  type        = string
  description = "REQUIRED.  Abbreviated product name, suitable for use in Azure naming.\nMust be 2-24 characters in length, all lowercase, no spaces, only dashes for punctuation.\nExample entry: my-product"
  validation {
    condition     = length(regexall("^[a-z][a-z0-9\\-]{1,23}$", var.product_name)) == 1
    error_message = "Value must be 2-24 characters in length, all lowercase, no spaces, only dashes for punctuation."
  }
}

variable "hpcc_version" {
  description = "REQUIRED.  The version of HPCC Systems to install.\nOnly versions in nn.nn.nn format are supported."
  type        = string
  validation {
    condition     = length(regexall("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}", var.hpcc_version)) == 1
    error_message = "Value must be in nn.nn.nn format."
  }
}

variable "enable_roxie" {
  description = "REQUIRED.  Enable ROXIE?\nThis will also expose port 8002 on the cluster.\nExample entry: false"
  type        = bool
}

variable "enable_elk" {
  description = "REQUIRED.  Enable ELK (Elasticsearch, Logstash, and Kibana) Stack?\nThis will also expose port 5601 on the cluster.\nExample entry: false"
  type        = bool
}

variable "extra_tags" {
  description = "REQUIRED.  Map of name => value tags that can will be associated with the cluster.\nFormat is '{\"name\"=\"value\" [, \"name\"=\"value\"]*}'.\nThe 'name' portion must be unique.\nTo add no tags, enter '{}'."
  type        = map(string)
}

variable "azure_region" {
  type        = string
  description = "REQUIRED.  The Azure region abbreviation in which to create these resources.\nMust be one of [\"eastus2\", \"centralus\"].\nExample entry: eastus2"
  validation {
    condition     = contains(["eastus2", "centralus"], var.azure_region)
    error_message = "Value must be one of [\"eastus2\", \"centralus\"]."
  }
}

variable "admin_ip_cidr_map" {
  description = "REQUIRED.  Map of name => CIDR IP addresses that can administrate this AKS.\nFormat is '{\"name\"=\"cidr\" [, \"name\"=\"cidr\"]*}'.\nThe 'name' portion must be unique.\nTo add no CIDR addresses, enter '{}'.\nThe corporate network and your current IP address will be added automatically, and these addresses will have access to the HPCC cluster as a user."
  type        = map(string)
}

variable "hpcc_user_ip_cidr_list" {
  description = "REQUIRED.  List of additional CIDR addresses that can access this HPCC Systems cluster.\nTo add no CIDR addresses, enter '[]'."
  type        = list(string)
}

variable "storage_account_name" {
  type        = string
  description = "OPTIONAL.  If you are attaching to an existing storage account, enter its name here.\nLeave blank if you do not have a storage account.\nIf you enter something here then you must also enter a resource group for the storage account.\nExample entry: my-product-sa"
}

variable "storage_account_resource_group_name" {
  type        = string
  description = "OPTIONAL.  If you are attaching to an existing storage account, enter its resource group name here.\nLeave blank if you do not have a storage account.\nIf you enter something here then you must also enter a name for the storage account."
}

variable "node_size" {
  type        = string
  description = "REQUIRED.  The VM size for each node in the HPCC Systems node pool.\nRecommend \"Standard_B4ms\" or better.\nSee https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general for more information."
}

variable "max_node_count" {
  type        = number
  description = "REQUIRED.  The maximum number of VM nodes to allocate for the HPCC Systems node pool.\nMust be 2 or more."
  validation {
    condition     = var.max_node_count >= 2
    error_message = "Value must be 2 or more."
  }
}

###############################################################################
# Unprompted variables that can be overridden within a .tfvars file
###############################################################################

variable "auto_connect" {
  description = "If true, creates (and possibly overwrites) a context for kubectl and sets it to the just-created AKS cluster."
  type        = bool
  default     = true
}
