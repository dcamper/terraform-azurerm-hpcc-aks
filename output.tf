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
