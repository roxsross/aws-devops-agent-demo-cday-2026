# DevOps Agent Space como infraestructura (Terraform)
# Basado en el sample oficial de AWS: github.com/aws-samples/sample-aws-devops-agent-terraform

terraform {
  required_version = ">= 1.0"
  required_providers {
    awscc  = { source = "hashicorp/awscc", version = "~> 1.0" }
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
    time   = { source = "hashicorp/time", version = "~> 0.9" }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "agent_space_name" {
  type    = string
  default = "unicorn-rentals-demo"
}

variable "agent_space_description" {
  type    = string
  default = "Space para la demo de Unicorn Rentals - La ultima guardia manual"
}

provider "awscc" {
  region = var.aws_region
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

# --- Rol del Agent Space (lo asume el servicio para investigar la cuenta) ---
data "aws_iam_policy_document" "agentspace_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["aidevops.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:aidevops:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agentspace/*"]
    }
  }
}

resource "aws_iam_role" "agentspace" {
  name               = "DevOpsAgentRole-AgentSpace-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.agentspace_trust.json
}

resource "aws_iam_role_policy_attachment" "agentspace_access" {
  role       = aws_iam_role.agentspace.name
  policy_arn = "arn:aws:iam::aws:policy/AIDevOpsAgentAccessPolicy"
}

data "aws_iam_policy_document" "agentspace_inline" {
  statement {
    sid       = "AllowCreateServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/resource-explorer-2.amazonaws.com/AWSServiceRoleForResourceExplorer"]
  }
}

resource "aws_iam_role_policy" "agentspace_inline" {
  name   = "AllowCreateServiceLinkedRoles"
  role   = aws_iam_role.agentspace.id
  policy = data.aws_iam_policy_document.agentspace_inline.json
}

# --- Rol del Operator App (acceso a la WebApp) ---
data "aws_iam_policy_document" "operator_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["aidevops.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:aidevops:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agentspace/*"]
    }
  }
}

resource "aws_iam_role" "operator" {
  name               = "DevOpsAgentRole-WebappAdmin-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.operator_trust.json
}

resource "aws_iam_role_policy_attachment" "operator_access" {
  role       = aws_iam_role.operator.name
  policy_arn = "arn:aws:iam::aws:policy/AIDevOpsOperatorAppAccessPolicy"
}

# --- Espera a que IAM propague antes de crear el Space ---
resource "time_sleep" "wait_for_iam" {
  create_duration = "30s"
  depends_on = [
    aws_iam_role_policy_attachment.agentspace_access,
    aws_iam_role_policy.agentspace_inline,
    aws_iam_role_policy_attachment.operator_access,
  ]
}

# --- El Agent Space ---
resource "awscc_devopsagent_agent_space" "main" {
  name        = var.agent_space_name
  description = var.agent_space_description
  operator_app = {
    iam = {
      operator_app_role_arn = aws_iam_role.operator.arn
    }
  }
  depends_on = [time_sleep.wait_for_iam]
}

# --- Asociacion de la cuenta primaria (monitor) ---
resource "awscc_devopsagent_association" "primary" {
  agent_space_id = awscc_devopsagent_agent_space.main.id
  service_id     = "aws"
  configuration = {
    aws = {
      assumable_role_arn = aws_iam_role.agentspace.arn
      account_id         = data.aws_caller_identity.current.account_id
      account_type       = "monitor"
      resources          = []
    }
  }
  depends_on = [awscc_devopsagent_agent_space.main]
}

output "agent_space_id" {
  value = awscc_devopsagent_agent_space.main.id
}

output "agent_space_arn" {
  value = awscc_devopsagent_agent_space.main.arn
}
