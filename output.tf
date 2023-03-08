output "url" {

  value       = format("http://%s.%s:8010",var.a_record_name, module.child_dns_zone.name)

  depends_on  = [module.child_dns_zone]
} 

output "eclwatchip" {
  value       = data.external.get_eclwatchip.result["ecl_watch_ip"]
} 
