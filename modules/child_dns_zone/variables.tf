variable "dns_zone_name_prefix" {
  type        = string
  description = "dns zone name prefix. The dns name will be var.dns_zone_name_prefix.<current_subscription_name>.azure.lnrsg.io"
  default     = ""
}

variable "hpcc_resource_group_name" {
  type        = string
  description = "Resource group where hpcc is created."
  default     = ""
}
