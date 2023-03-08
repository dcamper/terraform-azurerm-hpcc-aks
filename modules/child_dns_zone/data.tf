#-----------------------------------------------------------------------------
data "external" "current_subscription_info" {
  program = ["./modules/child_dns_zone/scripts/current_subscription_info.pl"]
}

#-----------------------------------------------------------------------------
# USAGE: data.external.child_dns_zone[0].result["child_dns_resource_group"]  OR  data.external.child_dns_zone[0].result["child_dns_name"]
data "external" "child_dns_zone" {
  count      = (var.dns_zone_name_prefix != "")? 1 : 0

  program = ["./modules/child_dns_zone/scripts/child_dns_zone.pl"]

  query = {
    "parent_subscription" : "${data.external.current_subscription_info.result["name"]}",
    "child_dns_name_prefix" : "${var.dns_zone_name_prefix}",
    "hpcc_resource_group" : "${var.hpcc_resource_group_name}"
  }

  depends_on = [data.external.current_subscription_info]
}

#-----------------------------------------------------------------------------
