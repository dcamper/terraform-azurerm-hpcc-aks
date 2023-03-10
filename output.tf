output "url" {

  value       = format("http://%s.%s:8010",var.a_record_name, module.child_dns_zone.name)

  depends_on  = [module.child_dns_zone]
}

output "eclwatchip" {
  value       = data.external.get_eclwatchip.result["ecl_watch_ip"]
}

output "advisor_recommendations" {
  value = data.azurerm_advisor_recommendations.advisor.recommendations
}

output "aks_login" {
  value = "az aks get-credentials --name ${module.kubernetes.name} --resource-group ${module.resource_group.name} --admin"
}

output "resource_group_name" {
  value = "${module.resource_group.name}"
}

output "stop_cluster_cmd" {
  value = "az aks stop --name ${module.kubernetes.name} --resource-group ${module.resource_group.name}"
}

output "start_cluster_cmd" {
  value = "az aks start --name ${module.kubernetes.name} --resource-group ${module.resource_group.name}"
}

output "azure_region" {
  value = module.resource_group.location
}

output "subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
}
