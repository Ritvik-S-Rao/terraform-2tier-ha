output "website_url" {
  description = "The public URL to access the web application"
  value       = "http://${module.compute.alb_dns_name}"
}

output "database_endpoint" {
  description = "The internal connection string for the database"
  value       = module.database.db_endpoint
}
