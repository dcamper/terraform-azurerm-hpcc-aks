output "advisor_recommendations" {
  value = data.azurerm_advisor_recommendations.advisor.recommendations
}

output "aks_login" {
  value = "az aks get-credentials --name ${module.kubernetes.name} --resource-group ${module.resource_group.name} --admin"
}

output "rsg_name" {
  value = "Resource group for created items: ${module.resource_group.name}"
}

output "stop_cluster_cmd" {
  value = "To stop the AKS cluster: az aks stop --name ${module.kubernetes.name} --resource-group ${module.resource_group.name}"
}

output "start_cluster_cmd" {
  value = "To restart the AKS cluster: az aks start --name ${module.kubernetes.name} --resource-group ${module.resource_group.name}"
}
