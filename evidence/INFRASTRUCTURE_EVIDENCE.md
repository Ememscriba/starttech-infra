# Infrastructure Evidence and Documentation

This document provides evidence that the StartTech infrastructure was successfully
deployed on AWS. Each section corresponds to a screenshot taken before the
infrastructure was destroyed, with an explanation of what each resource is,
why it exists, and how it connects to the rest of the system.

---

## 1. VPC — Virtual Private Cloud

**What this is:**
A VPC is a private, isolated network inside AWS. Think of it as building your
own walled city on Amazon's land. Nothing gets in or out unless you explicitly
allow it. Every other resource in this project lives inside this VPC.

**What the screenshot shows:**
The VPC named `starttech-vpc` with ID `vpc-01f23d7f9aa343634` in Available
state. You can also see `myapp-production-vpc` which is a separate project and
was not touched during this build.

**Why it matters:**
Without a VPC, AWS would place your resources in a default shared network with
no isolation. A dedicated VPC gives you full control over network topology,
routing, and security.

**What connects to it:**
Every single resource in this project — subnets, EC2 instances, load balancer,
Redis, security groups — all live inside this VPC.

---

## 2. Subnets

**What this is:**
Subnets divide the VPC into smaller network segments. This project uses four
subnets split across two AWS availability zones (physical data centers in
different buildings).

**What the screenshot shows:**
Four starttech subnets all in Available state:
- `starttech-public-subnet-1` — us-east-1a
- `starttech-public-subnet-2` — us-east-1b
- `starttech-private-subnet-1` — us-east-1a
- `starttech-private-subnet-2` — us-east-1b

**Why public and private subnets exist:**
Public subnets have a route to the internet through the Internet Gateway.
Resources here can be reached from the internet. The Application Load Balancer
lives here.

Private subnets have no direct route to the internet. Resources here cannot
be reached from outside. EC2 instances and Redis live here. This is intentional
security design — your application servers should never be directly reachable
from the internet.

**Why two availability zones:**
If one AWS data center goes down, the other keeps running. Spreading across
two availability zones means your application survives a physical infrastructure
failure on AWS's side.

**What connects to it:**
The ALB uses the two public subnets. EC2 instances use the two private subnets.
Redis uses the private subnets. The NAT Gateway sits in the first public subnet
so private subnet resources can reach the internet for updates without being
reachable from it.

---

## 3. Application Load Balancer

**What this is:**
The ALB is the front door of the application. It receives every HTTP request
from the internet and distributes them across EC2 instances. It also performs
health checks and stops sending traffic to any instance that stops responding.

**What the screenshot shows:**
`starttech-alb` in Active state, type Application, scheme Internet-facing,
connected to `vpc-01f23d7f9aa343634`.

**Why it matters:**
Without a load balancer, you would point your DNS directly at one EC2 instance.
If that instance goes down or gets overloaded, the application dies. The ALB
removes that single point of failure. It also lets the Auto Scaling Group add
and remove instances without changing your DNS.

**What connects to it:**
The ALB sits in the public subnets and forwards traffic to the target group
on port 8080. The ALB security group only allows inbound traffic on ports 80
and 443 from the internet. The EC2 security group only allows inbound traffic
from the ALB security group, so EC2 instances cannot be reached any other way.

---

## 4. Target Group

**What this is:**
A target group is the list of servers the ALB sends traffic to. The ALB does
not talk to EC2 instances directly — it talks to a target group, and the target
group manages the list of healthy instances.

**What the screenshot shows:**
`starttech-tg` on port 8080, protocol HTTP, target type Instance, attached to
`starttech-alb`.

**Why port 8080:**
The Go backend listens on port 8080 by default. The target group forwards
traffic to that port on each EC2 instance.

**Health checks:**
The target group sends a GET request to `/health` on each instance every 30
seconds. If an instance returns anything other than a 200 OK, the target group
marks it unhealthy and the ALB stops sending it traffic.

**What connects to it:**
The ALB listener on port 80 forwards all traffic to this target group. The Auto
Scaling Group registers each new EC2 instance with this target group
automatically when it launches.

---

## 5. Auto Scaling Group

**What this is:**
The ASG manages your fleet of EC2 instances automatically. It launches new
instances when demand increases and terminates them when demand drops. You
define the minimum, desired, and maximum number of instances and set the
conditions for scaling.

**What the screenshot shows:**
`starttech-asg` with 1 instance running, desired capacity 1, using launch
template `starttech-lt-20260330065351527400000`.

**Configuration:**
- Minimum: 1 instance always running
- Desired: 1 instance at normal load
- Maximum: 2 instances at peak load

**Scaling policies:**
A CloudWatch alarm triggers scale-up when CPU stays above 80% for two
consecutive 2-minute periods. A separate alarm triggers scale-down when CPU
stays below 20%. The 300 second cooldown period prevents rapid scaling up and
down in response to short traffic spikes.

**Note on desired capacity:**
The desired capacity is set to 1 instead of 2 because new AWS accounts have a
vCPU limit that prevents launching multiple t3 instances simultaneously. The
infrastructure is correctly configured for multi-instance operation and will
scale to 2 instances once the account limit is raised or a service quota
increase is approved.

**What connects to it:**
The ASG uses the launch template to define what each instance looks like when
it launches. Each new instance automatically registers with the target group
so the ALB starts sending it traffic.

---

## 6. S3 Buckets

**What this is:**
S3 is AWS object storage. It stores files. For this project, S3 serves two
purposes: hosting the React frontend static files, and storing the Terraform
state file.

**What the screenshot shows:**
Three buckets:
- `starttech-frontend-f466916d` — holds the built React application files
- `starttech-terraform-state-954692413962` — holds the Terraform state file
- `emem-aws-project` — a separate unrelated project, not touched

**Why the frontend lives in S3:**
A React application compiles to a folder of static HTML, CSS, and JavaScript
files. These files do not need a running server. S3 can serve them directly
as a website, which is far cheaper and more reliable than running a server
just to serve static files.

**Why the state file lives in S3:**
Terraform keeps track of what it has built in a state file. If this file only
exists on your laptop, the GitHub Actions pipeline cannot access it when it
runs on GitHub's servers. Storing it in S3 means both your laptop and the
pipeline can read and write the same state file. Versioning is enabled on the
state bucket so you can recover previous states if something goes wrong.

**What connects to it:**
The GitHub Actions frontend pipeline syncs the React build folder to the
frontend bucket after every successful build. CloudFront reads from the frontend
bucket and distributes the files globally. Terraform reads and writes the state
file bucket on every plan and apply operation.

---

## 7. ElastiCache Redis

**What this is:**
ElastiCache is AWS's managed caching service. This project uses Redis, an
in-memory data store that the backend application uses for two purposes:
caching frequently requested data so it does not have to hit MongoDB every time,
and storing session data so users stay logged in.

**What the screenshot shows:**
`starttech-redis` in Available state, engine version 7.0.7, node type
cache.t3.micro, running in the private subnet.

**Why managed Redis instead of running Redis on EC2:**
You could install Redis on an EC2 instance yourself. AWS ElastiCache handles
backups, patching, monitoring, and failover automatically. This is consistent
with the project's approach of using managed services for infrastructure
concerns so engineering effort stays focused on the application.

**Why Redis lives in the private subnet:**
Redis should never be reachable from the internet. The Redis security group
only allows inbound connections on port 6379 from the EC2 security group. Only
your application servers can talk to Redis. Nothing else can.

**What connects to it:**
The Go backend connects to Redis using the endpoint address
`starttech-redis.umnadz.0001.use1.cache.amazonaws.com:6379`. The connection
string gets passed to the application as an environment variable.

---

## 8. CloudWatch Dashboard

**What this is:**
A CloudWatch dashboard gives you a visual overview of your system health in
real time. Instead of checking multiple services separately, the dashboard
shows all your key metrics in one place.

**What the screenshot shows:**
`starttech-dashboard` created on 2026-03-30.

**What the dashboard contains:**
Three metric widgets:
- CPU Utilization of the Auto Scaling Group over time
- ALB Request Count showing traffic volume
- ALB 5XX Error Count showing application errors

**Why this matters:**
When something breaks at 2am, you need to see what changed. The dashboard
shows you at a glance whether the problem is high CPU, a traffic spike, or
application errors throwing 500 responses.

**What connects to it:**
The dashboard reads metrics from CloudWatch. AWS pushes EC2 and ALB metrics
to CloudWatch automatically. No agent or configuration needed for these
standard metrics.

---

## 9. CloudWatch Alarms

**What this is:**
Alarms watch specific metrics and trigger actions when those metrics cross
defined thresholds. This project has three alarms.

**What the screenshot shows:**
Three alarms:
- `starttech-high-cpu` — state OK, last updated 17:17
- `starttech-low-cpu` — state In Alarm, last updated 17:37
- `starttech-alb-errors` — state Insufficient data

**What each alarm does:**

`starttech-high-cpu` watches EC2 CPU utilization. If CPU stays above 80% for
two consecutive 2-minute periods it triggers the scale-up policy on the ASG,
which launches a new EC2 instance.

`starttech-low-cpu` watches EC2 CPU utilization. If CPU stays below 20% for
two consecutive 2-minute periods it triggers the scale-down policy, which
terminates one EC2 instance. This alarm shows In Alarm because the single
running instance has low CPU with no real traffic, which is expected behavior.

`starttech-alb-errors` watches the count of 5XX HTTP responses from the ALB
target group. If more than 10 errors occur within 5 minutes it triggers the
alarm. It shows Insufficient Data because there has been no traffic through
the load balancer yet, so there is no data to evaluate.

**What connects to it:**
The high-cpu alarm is connected to the `starttech-scale-up` Auto Scaling policy.
The low-cpu alarm is connected to the `starttech-scale-down` policy. The ALB
errors alarm currently has no action attached — in a production setup it would
send an SNS notification to an on-call engineer.

---

## 10 and 11. CloudWatch Log Groups

**What this is:**
Log groups collect and store application logs. Everything your application
prints to standard output gets collected here. You can search, filter, and
run analytics queries against your logs using CloudWatch Logs Insights.

**What the screenshots show:**
Three starttech log groups all in Standard class:
- `/starttech/alb` — load balancer access logs
- `/starttech/backend` — Go application logs
- `/starttech/frontend` — frontend access logs

Each log group has a 30-day retention policy, meaning logs older than 30 days
are automatically deleted to control storage costs.

**Why centralized logging matters:**
When your application runs on multiple EC2 instances, logs are scattered across
multiple servers. CloudWatch pulls all logs into one place so you can search
across every instance simultaneously. You can find an error that happened on
any server without SSH-ing into each one individually.

**Example queries you can run against these logs:**

Find all errors in the backend:
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

Find the slowest requests:
```
fields @timestamp, @message, @duration
| filter @duration > 1000
| sort @duration desc
```

**What connects to it:**
The EC2 launch template installs and starts the CloudWatch agent on every new
instance. The IAM role attached to the instances grants permission to write
logs to these groups. The agent collects application output and ships it to
the correct log group automatically.

---

## 12. IAM Users

**What this is:**
IAM users are identities with long-term credentials that can interact with AWS
programmatically or through the console. This screenshot shows the two users
created for this project.

**What the screenshot shows:**
Two users:
- `starttech-assessor` — created for the course assessor to verify the project
- `terraform-user` — the deployer user used by Terraform and GitHub Actions

**Why a dedicated assessor user:**
The assessor needs to log in and verify the infrastructure. Creating a dedicated
user with ViewOnlyAccess means they can see everything without being able to
change or delete anything. This follows the principle of least privilege.

**Why a dedicated deployer user:**
The root AWS account should never be used for automated operations. If the
deployer credentials are ever exposed, you delete that user and create a new
one. The root account stays untouched.

**IAM role for EC2:**
Separate from these users, an IAM role called `starttech-ec2-role` is attached
to every EC2 instance via an instance profile. This role grants the instance
permission to write logs to CloudWatch. The instance never needs hardcoded
credentials because it authenticates through the role automatically.

---

## Infrastructure Summary

Every resource in this project was provisioned by Terraform from a single
`terraform apply` command. The entire infrastructure can be recreated from
scratch in under 30 minutes by running:

```bash
cd terraform
terraform init
terraform apply
```

And destroyed completely with:

```bash
terraform destroy
```

This is the core value of infrastructure as code. The infrastructure is not
a collection of manual steps that exists only in someone's memory. It is a
precise, version-controlled description of exactly what needs to exist and how
it connects. Anyone with the repository and valid AWS credentials can reproduce
the entire environment identically.

