data "azurerm_dns_zone" "play" {
  name                = "us-hpccsystems-dev.azure.lnrsg.io"
  resource_group_name = "app-dns-prod-eastus2"
}

resource "azurerm_dns_a_record" "play-record_set" {
  name = "play-test"
  zone_name = data.azurerm_dns_zone.play.name
  resource_group_name = data.azurerm_dns_zone.play.resource_group_name
  ttl                 = 300
  records             = ["${data.external.get_eclwatchip.result["ecl_watch_ip"]}"]
}
