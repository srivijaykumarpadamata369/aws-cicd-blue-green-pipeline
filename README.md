# CI/CD Pipeline for a Microservices Architecture on AWS ECS

A production-pattern CI/CD pipeline demonstrating automated testing, container
vulnerability scanning, and zero-downtime blue/green deployments with
automatic rollback — built to run entirely within the AWS Free Tier.

## Architecture

```
GitHub push (main branch)
        │
        ▼
GitHub Actions CI
  ├─ pytest (unit tests)
  └─ Trivy (container vulnerability scan, fails build on CRITICAL/HIGH CVEs)
        │
        ▼
Build & push Docker image → Amazon ECR
        │
        ▼
AWS CodeDeploy (Blue/Green)
  ├─ Deploys new task set to GREEN target group
  ├─ Runs on test listener (port 8080) for validation
  ├─ Shifts production ALB traffic (port 80) from BLUE → GREEN
  └─ CloudWatch alarm (5xx rate) triggers automatic rollback on failure
        │
        ▼
Amazon ECS (EC2 launch type, single t3.micro) — Application Load Balancer
```

Authentication from CI to AWS uses **GitHub OIDC federation** — no long-lived
AWS access keys are stored as repository secrets.

## Why these specific design choices

| Decision | Reasoning |
|---|---|
| ECS on **EC2**, not Fargate | Fargate isn't Free Tier eligible; a single t3.micro gets 750 free hours/month |
| **No NAT Gateway** | Costs ~$32/month even idle; public subnets + tight security groups is the deliberate trade-off for a portfolio project |
| **SSM Session Manager**, no open SSH | No port 22 exposed anywhere, fully IAM-audited shell access |
| **OIDC for GitHub Actions** | No static AWS keys in CI — a real security control, not a checkbox |
| **ECR lifecycle policy** (keep last 5 images) | Stays under the 500MB/month Free Tier storage limit |
| **CloudWatch Logs, 7-day retention** | Keeps log storage cost effectively at zero |

## Repository structure

```
services/
  api-service/       # Flask microservice with /health endpoint
  worker-service/     # second service demonstrating multi-service handling
infra/                # Terraform: VPC, ECS, ALB, CodeDeploy, IAM (OIDC + least privilege)
.github/workflows/     # CI/CD pipeline definition
appspec.yaml           # CodeDeploy blue/green deployment spec
task-definition.json   # ECS task definition template
```

## Setup

### 1. Prerequisites
- AWS account (Free Tier), AWS CLI configured
- Terraform >= 1.5
- A GitHub repository containing this code

### 2. Provision infrastructure
```bash
cd infra
terraform init
terraform plan
terraform apply
```
Note the outputs — you'll need `github_actions_role_arn` for the next step,
and `alb_dns_name` to access the app once deployed.

### 3. Configure GitHub
- In `infra/iam.tf`, replace `YOUR_GITHUB_USERNAME/YOUR_REPO` with your actual
  repo path, then re-apply.
- In your GitHub repo settings → Secrets and variables → Actions, add:
  - `AWS_ROLE_ARN` = the `github_actions_role_arn` Terraform output

### 4. Push to trigger the pipeline
```bash
git push origin main
```
Watch the run under the **Actions** tab. On success, the app is reachable at
the `alb_dns_name` Terraform output.

## Demo: watching a bad deployment get rolled back automatically

This is the part worth walking an interviewer through directly.

1. In `services/api-service/app.py`, set `SIMULATE_FAILURE` to be read as
   `true`, or pass `SIMULATE_FAILURE=true` as a container environment
   variable in a new task definition revision.
2. Push the change. The pipeline builds and CodeDeploy begins shifting
   traffic to the new (green) task set.
3. The `/health` endpoint starts returning `500`, the ALB target group
   reports unhealthy targets, and the `high_5xx_rate` CloudWatch alarm
   (defined in `infra/codedeploy.tf`) breaches its threshold.
4. CodeDeploy's `alarm_configuration` + `auto_rollback_configuration`
   trigger an automatic rollback to the last healthy (blue) task set —
   no manual intervention.
5. Screenshot the CodeDeploy deployment timeline and the CloudWatch alarm
   state change for your portfolio.

This sequence is the direct, literal answer to "walk me through what
happens when a deployment fails" — because it's exactly what happens here.

## Cost management

- Set an **AWS Budget alarm** at $5–10 before deploying.
- Run `terraform destroy` when not actively demoing — the ALB and EC2
  instance are the only resources with meaningful hourly cost, and both
  are trivial to recreate with `terraform apply`.

## Possible extensions (not yet built — good interview talking points)
- `BeforeAllowTraffic`/`AfterAllowTraffic` Lambda hooks in `appspec.yaml` to
  run automated smoke tests against the green environment pre-cutover
- Remote Terraform state (S3 + DynamoDB locking) — commented scaffold
  already in `infra/main.tf`
- SonarCloud integration for static code quality gating (free for public repos)
