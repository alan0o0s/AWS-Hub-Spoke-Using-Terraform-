output "alb_dns_name" {
  value = module.platform.alb_dns_name
}

output "nlb_dns_name" {
  value = module.platform.nlb_dns_name
}

output "nlb_static_ips" {
  value = module.platform.nlb_static_ips
}
