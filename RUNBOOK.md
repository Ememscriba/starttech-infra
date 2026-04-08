# Operations Runbook

## Deploying Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Deploying Frontend Manually

```bash
cd starttech-application
./scripts/deploy-frontend.sh starttech-frontend-f466916d
```

## Deploying Backend Manually

```bash
cd starttech-application
./scripts/deploy-backend.sh <image-tag> salemscriba
```

## Running a Health Check

```bash
./scripts/health-check.sh starttech-alb-986580528.us-east-1.elb.amazonaws.com
```

## Rolling Back the Backend

If a deployment breaks production:

```bash
./scripts/rollback.sh <previous-image-tag> salemscriba
```

To find the previous image tag go to Docker Hub and check
the tags for salemscriba/starttech-backend.

## Checking Logs

Go to AWS Console, CloudWatch, Log groups and look inside:

- /starttech/backend for application errors
- /starttech/alb for traffic and request errors

Or use the queries in monitoring/log-insights-queries.txt
inside CloudWatch Logs Insights.

## Common Issues

### EC2 instance failing health checks

1. Check /starttech/backend log group for errors
2. Verify the Docker container is running on the instance
3. Check the security group allows port 8080 from the ALB

### Frontend not updating after deployment

1. Confirm the S3 sync completed in the GitHub Actions log
2. If CloudFront is enabled, check the cache invalidation ran

### Redis connection refused

1. Verify the EC2 security group ID is in the Redis
   security group inbound rules
2. Check the Redis endpoint in ElastiCache console
3. Confirm the backend has the correct REDIS_HOST variable

## Destroying Infrastructure

Only do this if you intend to delete everything:

```bash
cd terraform
terraform destroy
```
