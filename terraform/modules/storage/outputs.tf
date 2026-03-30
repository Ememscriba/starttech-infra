output "s3_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "s3_bucket_arn" {
  description = "ARN of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}
