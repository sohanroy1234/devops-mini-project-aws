# Jenkins Setup (AWS)

Terraform already installed Jenkins, Docker, Node 18, AWS CLI v2, jq and git on the EC2 server
and attached an IAM role, so there are **no AWS credentials to add**.

## 1. Unlock Jenkins

Open the `jenkins_url` Terraform output (`http://<ip>:8080`). If it doesn't load, wait a few minutes
(bootstrap log: `/var/log/jenkins-bootstrap.log` on the server).

Get the first-login password via Session Manager (no SSH key needed):

```bash
aws ssm start-session --region ap-south-1 --target <jenkins_instance_id>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

(Needs the AWS CLI Session Manager plugin. Alternative: set `jenkins_key_name` in tfvars and SSH in.)

Choose **Install suggested plugins**, then create your admin user.

## 2. Verify the server can reach AWS

In the SSM session:

```bash
sudo -u jenkins aws sts get-caller-identity     # should show the jenkins-role
sudo -u jenkins docker ps                        # should work without sudo
node -v && jq --version
```

If `docker ps` is denied: `sudo systemctl restart jenkins` (group membership needs a restart).

## 3. Plugins

`Manage Jenkins → Plugins → Available`: make sure these are installed —
**Pipeline**, **Git**, **JUnit**, **Timestamper**, **Workspace Cleanup**. (All are in the suggested set.)

## 4. Create the pipeline job

1. **New Item** → name `devops-mini-project-pipeline` → **Pipeline** → OK
2. **Pipeline → Definition:** `Pipeline script from SCM`
3. **SCM:** Git, **Repository URL:** your GitHub repo
   - Private repo: add a GitHub Personal Access Token as *Username with password* credentials and select it.
4. **Branch Specifier:** `*/main`   **Script Path:** `Jenkinsfile`
5. Save → **Build Now**

The Jenkinsfile polls Git every ~2 minutes (`pollSCM`), so pushes to `main` deploy automatically.
For instant triggers, add a GitHub webhook to `http://<jenkins-ip>:8080/github-webhook/` and tick
*GitHub hook trigger for GITScm polling*.

## 5. What each stage does

| Stage | Action |
|-------|--------|
| Checkout | Pulls code, builds tag `<build#>-<git-sha>` |
| Install & Test | `npm ci` + Jest; publishes JUnit results; fails the build on test failure |
| AWS Identity | Resolves account ID and ECR registry URL |
| Docker Build | Builds and tags the image |
| Push to ECR | Logs in with the instance role and pushes (main branch only) |
| Deploy to ECS | Registers a new task-definition revision, updates the service, waits for stability |
| Smoke Test | Polls the ALB `/health` until it reports the new version |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission denied ... docker.sock` | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins` |
| `Unable to locate credentials` | Instance profile missing — check the instance's IAM role in EC2 console |
| `AccessDenied ... iam:PassRole` | Task role names changed — re-run `terraform apply` |
| `RepositoryNotFound` | `ECR_REPO` in Jenkinsfile must equal Terraform `project_name` |
| Tasks keep restarting | `aws logs tail /ecs/devops-mini-project --follow --region ap-south-1` |
| `Smoke Test` times out | Check target health: EC2 console → Target Groups → `devops-mini-project-tg` |
