module "child_dns_zone" {
  source = "./modules/child_dns_zone"

  dns_zone_name_prefix     = "${var.dns_zone_name_prefix}"
  hpcc_resource_group_name = module.resource_group.name

}

resource "azurerm_dns_a_record" "mw-record_set" {
  count      = ((var.dns_zone_name_prefix != "") && (var.a_record_name != ""))? 1 : 0

  name = var.a_record_name
  zone_name = module.child_dns_zone.name
  resource_group_name = module.child_dns_zone.dns_resource_group
  ttl                 = 300
  records             = ["${data.external.get_eclwatchip.result["ecl_watch_ip"]}"]
}
