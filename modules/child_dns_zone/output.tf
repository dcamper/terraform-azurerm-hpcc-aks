output "name" {
  value       = data.external.child_dns_zone[0].result["child_dns_name"]
} 

output "dns_resource_group" {
  value       = data.external.child_dns_zone[0].result["child_dns_resource_group"]
} 
