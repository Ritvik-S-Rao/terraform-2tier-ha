output "alb_dns_name" {
  description = "The public DNS URL of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer"
  value       = aws_lb.app_alb.zone_id
}
