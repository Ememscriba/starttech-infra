output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.compute.alb_dns_name
}

output "s3_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = module.storage.s3_bucket_name
}
