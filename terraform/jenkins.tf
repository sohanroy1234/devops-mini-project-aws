# ---------------------------------------------------------------------------
# Jenkins server (EC2). It authenticates to AWS through an instance profile,
# so NO access keys are ever stored in Jenkins.
# ---------------------------------------------------------------------------

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_security_group" "jenkins" {
  count       = var.create_jenkins ? 1 : 0
  name        = "${var.project_name}-jenkins-sg"
  description = "Jenkins UI and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  count              = var.create_jenkins ? 1 : 0
  name               = "${var.project_name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Lets you open a shell with Session Manager (no SSH key needed)
resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  count      = var.create_jenkins ? 1 : 0
  role       = aws_iam_role.jenkins[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-privilege permissions for the pipeline
data "aws_iam_policy_document" "jenkins_pipeline" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid = "EcsTaskDefinitions"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EcsService"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [aws_ecs_service.app.id]
  }

  statement {
    sid       = "EcsDebug"
    actions   = ["ecs:ListTasks", "ecs:DescribeTasks"]
    resources = ["*"]
  }

  statement {
    sid       = "LookupAlb"
    actions   = ["elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"]
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "jenkins_pipeline" {
  count  = var.create_jenkins ? 1 : 0
  name   = "${var.project_name}-jenkins-pipeline"
  role   = aws_iam_role.jenkins[0].id
  policy = data.aws_iam_policy_document.jenkins_pipeline.json
}

resource "aws_iam_instance_profile" "jenkins" {
  count = var.create_jenkins ? 1 : 0
  name  = "${var.project_name}-jenkins-profile"
  role  = aws_iam_role.jenkins[0].name
}

resource "aws_instance" "jenkins" {
  count                       = var.create_jenkins ? 1 : 0
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.jenkins_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.jenkins[0].id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins[0].name
  key_name                    = var.jenkins_key_name != "" ? var.jenkins_key_name : null
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/jenkins-userdata.sh.tftpl", {
    aws_region = var.aws_region
  })

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-jenkins" }
}

resource "aws_eip" "jenkins" {
  count    = var.create_jenkins ? 1 : 0
  instance = aws_instance.jenkins[0].id
  domain   = "vpc"
}
