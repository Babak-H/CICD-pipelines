





@Library('dynamo-shared-lib') _
def podTemplateYaml = libraryResource('terraform.yaml')

terraformBuild {
    kubernetesLabel = 'terraform.yaml'
    kubernetesYaml = podTemplateYaml

    terraformVersion = '1.0.7'

    // Enable Terraform validation
    terraformValidate = false

    // Enable Sonar scanning
    sonarScan = false

    // Enable SSAP scanning
    ssapScan = false

    // Dynamo SEAL_ID for SSAP scanning
    sealId = '105250'

    // Enable Python Tests
    pythonTests = false
    
    // Bitbucket credentials
    bitbucketCredentials = 'BB_CREDS'
}




## Change Log

11/12/2023
- Terraform version upgraded to 1.x

24/04/2020
- Updated tags to follow new tagging approach (see here - https://confluence.dynamo.prd.aws.jpmchase.net/display/DIGPROJECT/Tagging+Approach).




data "aws_iam_policy_document" "sns_default_policy" {
  policy_id = "DefaultPolicy"
  statement {
    actions = ["SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
      "SNS:Receive"
    ]
    resources = [aws_sns_topic.sns_topic.arn]
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    sid = "DefaultPolicy"
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = var.allowed_accounts
    }
  }
}




data "aws_caller_identity" "current" {}

module "test_sns_notification" {
  source           = "../"
  environment      = var.environment
  seal_id          = var.seal_id
  deployment_id    = var.deployment_id
  kms_key_alias    = "alias/data-encryption/${var.environment}-DAT-SYS"
  topic_name       = "devops-NATs-Blackhole-notifications"
  allowed_accounts = [data.aws_caller_identity.current.account_id]
}




terraform {
  required_version = "~> 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}




variable "region" {
  description = "AWS Region in which to deploy the resources"
  type        = string
  default     = ""
}

variable "account_id" {
  description = "Account ID for Dynamo"
  type        = string
  default     = ""
}

variable "seal_id" {
  description = "SEAL ID for Dynamo"
  type        = string
  default     = ""
}

variable "deployment_id" {
  description = "Deployment ID for the Environment/Dynamo combination"
  type        = string
  default     = ""
}

variable "environment" {
  description = "The environment we are running in"
  type        = string
  default     = "DEV"
}





data "aws_caller_identity" "current" {}

module "object_naming" {
  source        = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git?ref=v1.0.101"
  friendly_name = var.topic_name
  use_guid      = var.use_guid
  environment   = var.environment
  seal_id       = var.seal_id
  deployment_id = var.deployment_id
}

resource "aws_sns_topic" "sns_topic" {
  name              = module.object_naming.object_name
  kms_master_key_id = var.kms_key_alias
  tags              = var.tags
}

module "iam_policy_merge_sns" {
  source = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-iam-policy-merge.git?ref=v2.0.0.1"
  source_documents = [
    data.aws_iam_policy_document.sns_default_policy.json,
    var.additional_policy
  ]
}

resource "aws_sns_topic_policy" "default" {
  arn        = aws_sns_topic.sns_topic.arn
  policy     = module.iam_policy_merge_sns.merged_document
  depends_on = [aws_sns_topic.sns_topic]
}





output "sns_arn" {
  value = aws_sns_topic.sns_topic.arn
}





variable "seal_id" {
  description = "SEAL id for Dynamo"
  type        = string
  default     = ""
}

variable "deployment_id" {
  description = "Deployment ID for the Environment/Dynamo combination"
  type        = string
  default     = ""
}

variable "kms_key_alias" {
  description = "The KMS Key alias used to encrypt this SNS topic"
  type        = string
  default     = ""
}

variable "use_guid" {
  description = "Determines whether a GUID should be used as part of the S3 Object Name"
  default     = true
}

variable "environment" {
  description = "Environment the object is deployed to"
  type        = string
  default     = ""
}

variable "topic_name" {
  description = "The name of the topic that is being created"
  type        = string
  default     = ""
}

variable "additional_policy" {
  description = "Additional Policy Object, when set provides additional permissions to this SNS topic"
  default     = "{\"statement\":[]}"
}

variable "tags" {
  description = "Expected tags for this object.  They are defaulted to 'UNKNOWN' to make it easy to identify tags on objects that need to be set."
  type        = map(string)
  default = {
    "fin.reg.chg.id"       = "313031"
    "dev.res.for.id"       = "UNKNOWN"
    "sys.res.appcomponent" = "SNS"
    "dyn.res.appcomponent" = "SNS"
    "sys.res.appname"      = "TOPIC"
    "dyn.res.appname"      = "TOPIC"
    "sys.res.env"          = "UNKNOWN"
    "dyn.res.env"          = "UNKNOWN"
    "sys.res.mon"          = "1"
    "dyn.res.mon"          = "1"
    "dev.res.data.class"   = "UNKNOWN"
    "release.version"      = "UNKNOWN"
    "protected"            = "false"
  }
}

variable "allowed_accounts" {
  description = "List of account ID's within this environment that can access this topic"
  type        = list(string)
  default     = []
}





version: 1.0
