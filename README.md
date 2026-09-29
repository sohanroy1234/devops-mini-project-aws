# DevOps Mini Project — Jenkins + Docker + AWS

Node/Express app deployed to **AWS ECS Fargate** behind an **Application Load Balancer**,
built and shipped by a **Jenkins** pipeline. Infrastructure is created with **Terraform**.
(GitHub Actions and Render have been removed.)

```
GitHub ──► Jenkins (EC2) ──► npm test ──► docker build ──► Amazon ECR
                                                              │
                          ALB ◄── ECS Fargate (2 tasks) ◄─────┘  register task def + update service
                           │
                       Internet  (http://<alb-dns>)
```

## Repo layout

| Path | Purpose |
|------|---------|
| `app/` | Express app, Jest tests |
| `Dockerfile` | Multi-stage, non-root image |
| `Jenkinsfile` | Checkout → Test → Build → Push to ECR → Deploy to ECS → Smoke test |
| `scripts/deploy-ecs.sh` | Registers a new task-definition revision and rolls the service |
| `scripts/smoke-test.sh` | Polls `/health` on the ALB until the new version is live |
| `terraform/` | VPC, ALB, ECR, ECS cluster/service, IAM, Jenkins EC2 |
| `docker-compose.yml`, `nginx/` | Local development only |
| `docs/JENKINS_SETUP.md` | Step-by-step Jenkins configuration |

## Deploy in 5 steps

**Prerequisites:** AWS account, AWS CLI configured (`aws configure`), Terraform >= 1.5, this repo pushed to GitHub.

1. **Provision AWS**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars   # set admin_cidr to YOUR_IP/32
   terraform init
   terraform apply
   ```
   Note the outputs: `app_url`, `jenkins_url`, `ecr_repository_url`.
2. **Wait ~5 min** for the Jenkins server to bootstrap, then open `jenkins_url`.
3. **Configure Jenkins** — follow [docs/JENKINS_SETUP.md](docs/JENKINS_SETUP.md) (unlock, plugins, create the pipeline job).
4. **Run the pipeline** (`Build Now`, or push to `main`). The first run pushes the first image and scales the service from 0 → 2 tasks.
5. **Open `app_url`** from the Terraform output. `/health` returns the deployed build version.

## Things to know

- **Region:** defaults to `ap-south-1` (Mumbai). If you change `aws_region` / `project_name` in Terraform, change the matching values in the `environment {}` block of the `Jenkinsfile`.
- **No AWS keys in Jenkins:** the Jenkins EC2 uses an IAM instance profile scoped to ECR push + ECS deploy only.
- **Rollback:** the ECS deployment circuit breaker automatically rolls back a failed rollout. To roll back manually, redeploy an older image tag.
- **Cost (approx., on-demand):** ALB ~$18/mo, 2 Fargate tasks (0.25 vCPU / 0.5 GB) ~$18/mo, Jenkins t3.small ~$15/mo. **Run `terraform destroy` when finished.**
- **Security:** the ALB serves plain HTTP. For production add an ACM certificate + HTTPS listener, and keep `admin_cidr` restricted to your IP.

## Local development

```bash
cd app && npm ci && npm test && cd ..
docker compose up --build        # app on :4500, via nginx on :9090
```

## Tear down

```bash
cd terraform && terraform destroy
```

## Endpoints

| URL | Description |
|-----|-------------|
| `GET /` | Dashboard UI |
| `GET /health` | Health check JSON (used by ALB, ECS and the smoke test) |
| `GET /api/info` | App info & stats |
