data "azurerm_dns_zone" "play" {
  count      = ((var.dns_zone_name != "") && (var.dns_zone_resource_group_name != "") && (var.a_record_name != ""))? 1 : 0

  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_dns_a_record" "my-record_set" {
  count      = ((var.dns_zone_name != "") && (var.dns_zone_resource_group_name != "") && (var.a_record_name != ""))? 1 : 0

  name = var.a_record_name
  zone_name = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 300
  records             = ["${data.external.ecl_watch_ip.result["ip"]}"]
}
