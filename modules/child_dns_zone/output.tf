output "name" {
  value       = (var.dns_zone_name_prefix != "")? data.external.child_dns_zone[0].result["child_dns_name"] : null
} 

output "dns_resource_group" {
  value       = (var.dns_zone_name_prefix != "")? data.external.child_dns_zone[0].result["child_dns_resource_group"] : null
} 
