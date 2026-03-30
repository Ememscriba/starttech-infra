resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-frontend"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name        = "${var.project_name}-redis-subnet-group"
    Environment = var.environment
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [var.redis_security_group_id]

  tags = {
    Name        = "${var.project_name}-redis"
    Environment = var.environment
  }
}
