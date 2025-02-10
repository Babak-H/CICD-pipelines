#####################################
# LOCAL VALUES
#####################################

locals {
  resource_prefix               = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}"
  resource_name                 = var.kubernetes_serviceaccount
  role_name                     = "${local.resource_prefix}-${local.resource_name}"
  role_arn                      = "arn:aws:iam::${var.account_id}:role/${local.role_name}"
  role_permissions_boundary_arn = "arn:aws:iam::${var.account_id}:policy/pave/${lower(var.account_role)}/${var.seal_id}-EMEA-${upper(var.environment)}-${upper(var.account_role)}/permissions_boundary/${var.seal_id}-EMEA-${var.environment}-${upper(var.account_role)}-permissionBoundary"
  kubernetes_oidc_arn           = "arn:aws:iam::${var.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${var.oidc}"
  kubernetes_oidc_url           = "https://oidc.eks.${var.region}.amazonaws.com/id/${var.oidc}"
  cluster_name                  = "dn-${lower(var.environment)}-vault"

  tags = {
    "dev.res.for.id"       = "${var.seal_id}"
    "dyn.res.appname"      = "Vault"
    "dyn.res.appcomponent" = "Vault"
    "dyn.res.env"          = "${var.environment}"
    "fin.res.chg.id"       = "313031"
    "dyn.res.mon"          = "1"
    "sys.res.env"          = "BETA"
  }
}

#####################################
# DATA SOURCES
#####################################

data "aws_iam_policy_document" "assume_role_with_oidc" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [
        local.kubernetes_oidc_arn
      ]
    }
    condition {
      test     = "StringEquals"
      variable = format("%s:sub", replace(local.kubernetes_oidc_url, "https://", ""))
      values = [
        format("system:serviceaccount:%s:%s", var.vault_namespace, var.kubernetes_serviceaccount)
      ]
    }

    condition {
      test     = "StringEquals"
      variable = format("%s:aud", replace(local.kubernetes_oidc_url, "https://", ""))
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_eks_cluster" "eks-cluster" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.cluster_name
}

data "aws_caller_identity" "current" {}

#####################################
# IAM Role
#####################################

module "tm_vault_monitor_iam_policy" {
  source                        = "../modules/tm_vault_monitor_role"
  role_name                     = local.role_name
  assume_policy                 = data.aws_iam_policy_document.assume_role_with_oidc.json
  role_permissions_boundary_arn = local.role_permissions_boundary_arn
  tags                          = local.tags

}



terraform {
  backend "s3" {
    key      = "tnn_core_vault/tm-vault-monitor-sa.tfstate"
    role_arn = "arn:aws:iam::${var.account_id}:role/pave/${lower(var.account_role_tf)}/${var.seal_id}-EMEA-${upper(var.environment)}-${upper(var.account_role_tf)}"
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/pave/${lower(var.account_role)}/${var.seal_id}-EMEA-${upper(var.environment)}-${upper(var.account_role)}"

  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks-cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks-cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}




variable "environment" {
  description = "Short code for the environment"
  type        = string
  default     = "dcore"
}

variable "environment_name" {
  description = "Short code for the environment"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "seal_id" {
  description = "SEAL id for Dynamo"
  type        = string
  default     = "105250"
}

variable "deployment_id" {
  description = "Deployment ID for the Environment/Dynamo combination"
  type        = string
  default     = "0000ie"
}

variable "account_id" {
  description = "The AWS Account ID to deploy the System Resources"
  type        = string
  default     = "279924677952"
}

variable "account_role" {
  description = "The AWS Account Role to deploy the System Resources"
  type        = string
  default     = "INFRADEPLOYER"
}

variable "account_role_tf" {
  description = "The AWS Account Role to deploy the System Resources"
  type        = string
  default     = "TFSTATEMANAGER"
}

variable "aws_assume_role" {
  description = "SpinnakerManagedRolePave/infradeployer role to use"
  type        = string
  default     = "arn:aws:iam::279924677952:role/105250-EMEA-DCORE-INFRADEPLOYER"
}

#variable "role_arn" {
#  type        = string
#  description = "The ARN of the role used to deploy Terraform resources"
#}


#variable "role_permissions_boundary_arn" {
#  type        = string
#  description = "ARN of the permissions boundary to apply to the IAM role"
#}

variable "cluster_name" {}

variable "vault_namespace" {
  type        = string
  description = "Vault Namespace in the cluster"
  default     = "icb-ledgers-mon"
}

variable "kubernetes_serviceaccount" {
  type        = string
  description = "K8s service account to associate with IAM role"
  default     = "vault-monitor-sa"
}

variable "oidc" {
  type        = string
  description = "OIDC ID to bind K8s service account to the AWS account"
  default     = "0E11A85F33484962D4BB21362C83043E"
}






#####################################
# DATA SOURCES
#####################################
data "aws_iam_policy_document" "policy" {
  count = var.skip ? 0 : 1

  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "secretsmanager:ListSecrets",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "rds:DescribeDBClusters"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

#####################################
# IAM Role
#####################################
resource "aws_iam_role" "iam_role" {
  name                 = var.role_name
  path                 = "/"
  permissions_boundary = try(var.role_permissions_boundary_arn, "")
  assume_role_policy   = var.assume_policy
  tags                 = var.tags
  count                = var.skip ? 0 : 1
}

resource "aws_iam_role_policy" "monitor_role_policy" {
  name = "${aws_iam_role.iam_role[0].name}_role_policy"
  role = aws_iam_role.iam_role[0].id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "iam:CreateServiceLinkedRole",
          "Resource" : "*",
          ###To do: Limit the resources
          "Condition" : {
            "StringEquals" : {
              "iam:AWSServiceName" : "s3.amazonaws.com"
            }
          }
        },
        {
          "Effect" : "Allow",
          "Action" : ["kms:GenerateDataKey", "kms:Decrypt"],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : "s3:PutObject",
          "Resource" : "*"
        }
      ]
    }
  )
}

#####################################
# IAM Policy
#####################################
resource "aws_iam_policy" "policy" {
  name   = "${aws_iam_role.iam_role[0].name}_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.policy[0].json
  tags   = var.tags
  count  = var.skip ? 0 : 1
}

#####################################
# IAM Policy Attachment
#####################################
resource "aws_iam_policy_attachment" "policy_attachment" {
  name       = "${aws_iam_role.iam_role[0].name}_policy_attachment"
  roles      = ["${var.role_name}"]
  policy_arn = aws_iam_policy.policy[0].arn
  count      = var.skip ? 0 : 1
}



output "role_id" {
  description = "The role's ID"
  value       = try(aws_iam_role.iam_role[0].id, "")
}

output "role_arn" {
  description = "The ARN assigned by AWS to this role"
  value       = try(aws_iam_role.iam_role[0].arn, "")
}

output "role_name" {
  description = "The name of the role"
  value       = try(aws_iam_role.iam_role[0].name, "")
}

output "role_unique_id" {
  description = "The unique ID of the role in IAM"
  value       = try(aws_iam_role.iam_role[0].unique_id, "")
}

output "role_tags" {
  description = "The roles tag document"
  value       = try(aws_iam_role.iam_role[0].tags_all, "")
}

output "policy_id" {
  description = "The policy's ID"
  value       = try(aws_iam_policy.policy[0].id, "")
}

output "ploicy_arn" {
  description = "The ARN assigned by AWS to this policy"
  value       = try(aws_iam_policy.policy[0].arn, "")
}

output "policy_name" {
  description = "The name of the policy"
  value       = try(aws_iam_policy.policy[0].name, "")
}

output "policy_path" {
  description = "The path of the policy in IAM"
  value       = try(aws_iam_policy.policy[0].path, "")
}

output "policy" {
  description = "The policy document"
  value       = try(aws_iam_policy.policy[0].policy, "")
}



variable "role_name" {}

variable "assume_policy" {}

variable "role_permissions_boundary_arn" {
  type        = string
  description = "ARN of the permissions boundary to apply to the IAM role"
}

variable "tags" {
  type        = map(string)
  description = "Tags used in AWS resources"
}

variable "skip" {
  description = "Should resource creation be skipped? Useful for test accounts that you may only need in certain environments. Setting to true will cause the 'count' of all resources in this module to be '0' and those resources will be not be created."
  default     = false
}



terraform {
  required_version = ">= 0.12"
}





terraform {
  required_version = ">= 1.0.7"
  backend "s3" {
    key      = "hault-operator/pave/terraform-eu-west-1.tfstate"
    encrypt  = true
    region   = "eu-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.8.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  assume_role {
    role_arn = local.deploy_role_arn
  }
}

locals {
  # For local debugging - set --var assume_role_format=
  deploy_role_arn = var.assume_role_format == "" ? "" : format(
    var.assume_role_format,
    var.account_id,
    var.seal_id,
    upper(var.environment),
  )
}

module "basednvault" {
  source          = "../modules/pave"
  account_id      = var.account_id
  environment     = var.environment
  namespace       = var.namespace
  seal_id         = var.seal_id
  service_account = var.service_account
  deployment_id   = var.deployment_id

  tags = module.object_naming.tags
}


module "sys_res_env" {
  source      = "git::ssh://git@bitbucket.dynamo.prd.aws.jpmchase.net/scm/DSVC/core-vault.git//terraform/modules/naming?ref=4.6.283"
  environment = var.environment
}

module "object_naming" {
  source               = "git::ssh://git@bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git?ref=v1.0.102"
  friendly_name        = "Hault"
  dev_res_for_id       = var.seal_id
  dyn_res_appcomponent = "Hault"
  dyn_res_env          = var.environment
  fin_res_chg_id       = "313031"
  dyn_res_mon          = "1"
  sys_res_env          = module.sys_res_env.sys_res_env
  dyn_res_owner        = "ICB_Ledgers"
}


variable "account_id" {
  type = string
}

variable "environment" {
  description = "Environment the object is deployed to"
  type        = string
}

variable "namespace" {
  type    = string
  default = "105250-core-hault"
}

variable "seal_id" {
  type    = string
  default = "105250"
}

variable "deployment_id" {
  description = "Deployment ID for environment into which the object is being deployed"
  type        = string
  default     = "0000ie"
}

variable "service_account" {
  type    = string
  default = "core-hault"
}

variable "assume_role_format" {
  type        = string
  description = "Role arn that would be assumed for deployment"
  default     = "arn:aws:iam::%s:role/pave/infradeployer/%s-EMEA-%s-INFRADEPLOYER"
}



bucket     = "105250-0000ie-ncore-terraform-state"
kms_key_id = "arn:aws:kms:eu-west-1:411451773233:key/d81e2c51-c0c1-46d0-9022-b8a9723aeb74"
role_arn   = "arn:aws:iam::411451773233:role/pave/tfstatemanager/105250-EMEA-NCORE-TFSTATEMANAGER"




terraform {
  required_version = ">= 1.0.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.8.0"
    }
  }
}

data "aws_kms_key" "dest_dat_sys" {
  key_id = "alias/data-encryption/${upper(var.environment)}-DAT-SYS"
}

locals {
  role_name = var.service_account
  role_arn  = module.oidc_add_account.role_arn

  roles = [
    local.role_arn,
  "arn:aws:iam::${var.account_id}:root"]
}

module "bucket" {
  source        = "git::ssh://git@bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-s3.git//s3-bucket?ref=v1.0.8"
  bucket_name   = "hault-unseal-keys"
  kms_key_arn   = data.aws_kms_key.dest_dat_sys.arn
  seal_id       = var.seal_id
  deployment_id = var.deployment_id
  environment   = var.environment
  tags          = var.tags
  non_vpc_aws_service_roles_arn = [
  local.role_arn]
  additional_policy_statements = data.aws_iam_policy_document.policy_with_roles.json
  vpc_endpoint_ids             = []
}

data "aws_iam_policy_document" "policy_with_roles" {
  statement {
    sid    = "DenyIncorrectEncryptionKey"
    effect = "Deny"
    actions = [
      "s3:PutObject"
    ]

    principals {
      type = "AWS"
      identifiers = [
      "*"]
    }

    resources = [
      module.bucket.s3_bucket_arn,
      "${module.bucket.s3_bucket_arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false"
      ]
    }
  }
}

data "aws_iam_policy_document" "kms_policy" {
  version = "2012-10-17"
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    resources = [
    "*"]
    principals {
      type        = "AWS"
      identifiers = local.roles
    }
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:TagResource"
    ]
  }
}


resource "aws_kms_key" "hault-cmk" {
  description         = "Hault Unseal Keys"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_policy.json
  tags                = var.tags
}

resource "aws_kms_alias" "alias" {
  target_key_id = aws_kms_key.hault-cmk.key_id
  name          = "alias/${upper(var.environment)}-hault-unseal"
}

module "oidc_add_account" {
  source                   = "git::ssh://git@bitbucket.dynamo.prd.aws.jpmchase.net/scm/sre/icb-ledgers-core-vault.git//terraform/modules/oidc?ref=4.6.375"
  environment              = var.environment
  account_id               = var.account_id
  seal_id                  = var.seal_id
  deployment_id            = var.deployment_id
  serviceaccount_name      = var.service_account
  serviceaccount_namespace = var.namespace
  role_name                = local.role_name
  tags                     = var.tags
}

resource "aws_iam_role_policy" "hault_access_policy" {
  name = "hault_policy"
  role = "105250-0000ie-${lower(var.environment)}-core-hault"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
         {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucketVersions",
        "s3:ListBucketByTags",
        "s3:ListBucket",
        "s3:ListAllMyBuckets",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersion",
        "s3:GetObjectTagging",
        "s3:GetObjectRetention",
        "s3:GetObjectLegalHold",
        "s3:GetObjectAcl",
        "s3:GetObject",
        "s3:GetLifecycleConfiguration",
        "s3:GetInventoryConfiguration",
        "s3:GetEncryptionConfiguration",
        "s3:GetBucketWebsite",
        "s3:GetBucketVersioning",
        "s3:GetBucketTagging",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketPolicyStatus",
        "s3:GetBucketPolicy",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetBucketNotification",
        "s3:GetBucketLogging",
        "s3:GetBucketLocation",
        "s3:GetBucketCORS",
        "s3:GetBucketAcl",
        "s3:GetAccountPublicAccessBlock"
        ],
        "Resource": [
        "${module.bucket.s3_bucket_arn}",
        "${module.bucket.s3_bucket_arn}/*"
        ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:ListResourceTags",
        "kms:ListKeys",
        "kms:ListKeyPolicies",
        "kms:ListGrants",
        "kms:ListAliases",
        "kms:GetKeyPolicy",
        "kms:DescribeKey",
        "kms:DescribeCustomKeyStores",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
        ],
        "Resource": [
        "${data.aws_kms_key.dest_dat_sys.arn}",
        "${aws_kms_key.hault-cmk.arn}"
      ]
    }
  ]
}
EOF
}



output "cmk_arn" {
  value = aws_kms_key.hault-cmk.arn
}



variable "account_id" {
  type = string

}

variable "service_account" {
  type = string
}

variable "namespace" {
  type = string
}

variable "seal_id" {
  type = string
}

variable "deployment_id" {
  description = "Deployment ID for environment into which the object is being deployed"
  type        = string
}
variable "tags" {
  type        = map(any)
  default     = {}
  description = "A map of additional tags"
}

variable "environment" {
  description = "Environment the object is deployed to"
  type        = string
}






locals {
  vault_tools_role_name             = "${local.name_prefix}-vault-tools-role"
  infradeployer_permission_boundary = "arn:aws:iam::${var.account_id}:policy/pave/infradeployer/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER/permissions_boundary/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER-permissionBoundary"
  policy_path                       = "/icbLedgers/"
}

##################################################################
# Create IAM Role for TM vault-tools
###################################################################

resource "aws_iam_role" "vault-tools-role" {
  name                 = local.vault_tools_role_name
  permissions_boundary = local.infradeployer_permission_boundary
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${var.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${var.oidc}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "oidc.eks.eu-west-1.amazonaws.com/id/${var.oidc}:sub" : [
              "system:serviceaccount:${var.k8s_vault_tools_namespace}:${var.k8s_vault_tools_service_account}"
            ],

          }
        }
      }
    ]
  })
  tags = module.object_naming.tags
}

resource "aws_iam_role_policy_attachment" "vault_tools_role_policies" {
  for_each   = { for policy in local.vault_tools_role_policies : policy.name => policy.arn }
  policy_arn = each.value
  role       = aws_iam_role.vault-tools-role.name
}

resource "aws_iam_policy" "vault-backup-bucket-policy" {
  name   = "${local.name_prefix}-VaultBackupBucket"
  policy = data.aws_iam_policy_document.vault-backup-bucket.json
  path   = local.policy_path
  tags   = module.object_naming.tags
}

data "aws_iam_policy_document" "vault-backup-bucket" {
  statement {
    sid = "tnnCoreVaultKey"
    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:Decrypt"
    ]
    effect = "Allow"
    resources = [
      aws_kms_key.s3_bucket_key.arn,
      aws_kms_alias.s3_bucket_key_alias.arn
    ]
  }
  statement {
    sid = "vaultBackupBucket"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:RestoreObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging"
    ]
    effect = "Allow"
    resources = [
      module.s3-vault-backup-bucket.s3_bucket_arn,
      "${module.s3-vault-backup-bucket.s3_bucket_arn}/*",
    ]
  }
}

##################################################################
# Policy for the vault operator role
###################################################################
resource "aws_iam_policy" "tm-vault-secret-manager-policy" {
  name = "${local.name_prefix}-TMVaultSecretManagerAccess"
  #  description = "Policy to gran access to the /jpmc/* secrets"
  path = local.policy_path

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:ListSecrets"
        ],
        Resource : "*"
      },
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:PutSecretValue"
        ],
        Resource : "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${var.vault_namespace}/jpmc/*"
      }
    ]
  })
}

resource "aws_iam_policy" "tm-vault-service-account-secret-access-policy" {
  name = "${local.name_prefix}-TMVaultServiceAccountSecretsAccess"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:GetSecretValue"
        ],
        Resource : "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${var.seal_id}-${var.deployment_id}-${lower(var.environment)}-sa-reposting-vault-tools-tennessee-token-*"
      },
      {
        Effect : "Allow",
        Action : [
          "kms:Decrypt"
        ],
        Resource : "*",
        Condition : {
          "ForAnyValue:StringEquals" : {
            "kms:ResourceAliases" : "alias/${var.seal_id}-${var.deployment_id}-${upper(var.environment)}-sa-token-rotator-key"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "tm-vault-parameter-store-read-policy" {
  name = "${local.name_prefix}-TMVaultParameterStoreReadAccess"
  path = local.policy_path

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory",
          "ssm:DescribeParameters"
        ],
        Resource : "arn:aws:ssm:${var.region}:${var.account_id}:parameter/tm_vault/db_pointer"
      }
    ]
  })

  tags = module.object_naming.tags
}



resource "aws_kms_key" "s3_bucket_key" {
  description         = "Vault Tools S3 bucket Key for encrypt/decrypt"
  enable_key_rotation = true
  tags                = module.object_naming.tags
  policy              = data.aws_iam_policy_document.kms_key_logs_policy.json
}

resource "aws_kms_alias" "s3_bucket_key_alias" {
  name          = "alias/${var.seal_id}-${var.deployment_id}-${var.environment}-vault-tools-s3-key"
  target_key_id = aws_kms_key.s3_bucket_key.key_id
}

data "aws_iam_policy_document" "kms_key_logs_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow CWL Service Principal usage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }
}




locals {
  name_prefix = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}"
  bucket_name = "${local.name_prefix}-vault-backup"
  vault_tools_role_policies = [
    aws_iam_policy.vault-backup-bucket-policy,
    aws_iam_policy.tm-vault-secret-manager-policy,
    aws_iam_policy.tm-vault-service-account-secret-access-policy,
    aws_iam_policy.tm-vault-parameter-store-read-policy,
  ]
}



module "sys_res_env" {
  source      = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/SRE/icb-ledgers-core-vault.git//terraform/modules/naming?ref=4.6.426"
  environment = var.environment
}

module "object_naming" {
  source               = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git?ref=v1.0.102"
  friendly_name        = "vault-backup"
  dev_res_for_id       = var.seal_id
  dyn_res_appname      = "tm_vault"
  dyn_res_appcomponent = "vault-tools"
  dyn_res_env          = var.environment
  fin_res_chg_id       = "313031"
  dyn_res_mon          = "1"
  sys_res_env          = module.sys_res_env.sys_res_env
}



output "vault_backup_name" {
  value = module.s3-vault-backup-bucket.s3_bucket_name
}

output "vault_tools_role_arn" {
  value = aws_iam_role.vault-tools-role.arn
}



module "s3-vault-backup-bucket" {
  source             = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-s3//s3-bucket?ref=v1.0.8"
  bucket_name        = local.bucket_name
  custom_bucket_name = true
  kms_key_arn        = aws_kms_key.s3_bucket_key.arn
  seal_id            = var.seal_id
  deployment_id      = var.deployment_id
  environment        = var.environment
  acl                = null
  vpc_endpoint_ids   = var.vpc_endpoints_s3

  expiration_days = var.bucket_expiration_days
  transition_days = var.bucket_transition_days

  # FIXME(CPEI-1163): I need to rewrite the whole DenyNonVPCEndpointNonJPMCIPConnections statement as currently there is no access by AWS service.
  # enable_aws_service_access = true
  additional_policy_statements = data.aws_iam_policy_document.logs_access.json

  tags = module.object_naming.tags
}



data "aws_iam_policy_document" "logs_access" {
  statement {
    sid = "CloudWatchLogsAccess"
    actions = [
      "s3:PutObject"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${local.bucket_name}/*"
    ]
    principals {
      type = "Service"
      identifiers = [
        "logs.${var.region}.amazonaws.com"
      ]
    }
  }
  statement {
    sid    = "DenyNonVPCEndpointNonJPMCIPConnections"
    effect = "Deny"
    actions = [
      "s3:*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:s3:::${local.bucket_name}/*"
    ]

    condition {
      test     = "NotIpAddress"
      variable = "aws:SourceIp"
      values = [
        "159.53.0.0/16",
        "146.143.0.0/16",
        "170.148.0.0/16",
        "103.246.196.0/23",
        "161.121.0.0/16"
      ]
    }

    condition {
      test     = "BoolIfExists"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"
      values   = var.vpc_endpoints_s3
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalArn"
      values   = []
    }
  }
}



locals {
  aws_assume_role = var.assume_role_format != "" ? format(var.assume_role_format, var.account_id, var.environment) : ""
}

terraform {
  backend "s3" {
    key     = "tnn_core_vault/vault_tools.tfstate"
    encrypt = true
    region  = "eu-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  required_version = ">1.0"
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = local.aws_assume_role
  }
}




variable "environment" {
  description = "Short code for the environment"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "seal_id" {
  description = "SEAL id for Dynamo"
  type        = string
  default     = "105250"
}

variable "deployment_id" {
  description = "Deployment ID for the Environment/Dynamo combination"
  type        = string
  default     = "0000ie"
}

variable "account_id" {
  description = "The AWS Account ID to deploy the System Key to"
  type        = string
}

variable "oidc" {
  description = "ID of the OIDS Provider for the EKS cluster."
  type        = string
}

variable "k8s_vault_tools_service_account" {
  type    = string
  default = "vault-tools-sa"
}
variable "k8s_vault_tools_namespace" {
  type    = string
  default = "105250-vault-operators"
}

variable "vpc_endpoints_s3" {
  description = "VPC Endpoint id to allow access to the S3 buckets"
  type        = list(string)
}

// Buckets
variable "bucket_expiration_days" {
  description = "Number of days when the objects expire in the bucket."
  type        = number
  default     = 365
}
variable "bucket_transition_days" {
  description = "Number of days when the objects are transitioned to Glacier in the bucket."
  type        = number
  default     = 30
}

variable "assume_role_format" {
  description = "Format of the role that will be assumed. Might be set to null to use the current role (not assume)"
  type        = string
  default     = "arn:aws:iam::%s:role/pave/infradeployer/105250-EMEA-%s-INFRADEPLOYER"
}

variable "vault_namespace" {
  description = "K8s namespace of the core vault installation."
  type        = string
  default     = "105250-core-vault"
}





#s3 bucket with kms
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 0.12"
}

data "aws_caller_identity" "current" {
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  change_owner = var.replication_target_account_id == local.account_id ? "0" : var.replication_target_force_original_owner == "1" ? "0" : "1"

  tags = merge(
    var.tags,
    {
      "CORE_BACKUPS_RETENTION" = "NOBACKUP"
    },
  )
}

module "object_naming" {
  source        = "../modules/object-naming"
  friendly_name = var.bucket_name
  use_guid      = var.use_guid
  environment   = var.environment
  seal_id       = var.seal_id
  deployment_id = var.deployment_id
}

data "aws_cloudformation_export" "LogBucket-Name" {
  name = var.logbucket_name
}

data "aws_cloudformation_export" "LogBucket-Prefix" {
  name = var.log_prefix
}

resource "aws_s3_bucket" "s3_bucket_keep_owner" {
  count         = var.enabled && local.change_owner == "0" ? 1 : 0
  bucket        = module.object_naming.object_name
  tags          = local.tags
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "versioning" {
  count  = var.enabled && local.change_owner == "0" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_keep_owner[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  count  = var.enabled && local.change_owner == "0" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_keep_owner[0].id

  rule {
    id     = "transition"
    status = (0 < var.transition_days && var.transition_days < var.expiration_days) ? "Enabled" : "Disabled"

    transition {
      storage_class = coalesce(var.transition_class, "GLACIER")
      days          = var.transition_days != 0 ? var.transition_days : 999
    }
  }

  rule {
    id     = "noncurrent_version_transition"
    status = (0 < var.transition_days && var.transition_days < var.expiration_days) ? "Enabled" : "Disabled"

    noncurrent_version_transition {
      storage_class   = coalesce(var.transition_class, "GLACIER")
      noncurrent_days = var.transition_days != 0 ? var.transition_days : 999
    }
  }

  rule {
    id     = "expiration"
    status = "Enabled"

    expiration {
      days = var.expiration_days
    }
  }

  rule {
    id     = "object_delete_marker_expiration"
    status = "Enabled"

    expiration {
      expired_object_delete_marker = true #needs to be a separated rule from the main object expiry rule.
    }
  }

  rule {
    id     = "noncurrent_expiration"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort_incomplete_upload"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  count  = var.enabled && local.change_owner == "0" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_keep_owner[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_logging" "logging" {
  count  = var.enabled && local.change_owner == "0" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_keep_owner[0].id

  target_bucket = data.aws_cloudformation_export.LogBucket-Name.value
  target_prefix = data.aws_cloudformation_export.LogBucket-Prefix.value
}

resource "aws_s3_bucket_public_access_block" "deny_public_access" {
  count                   = var.enabled && local.change_owner == "0" ? 1 : 0
  bucket                  = aws_s3_bucket.s3_bucket_keep_owner[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "s3-bucket-policy" {
  enabled                       = var.enabled
  source                        = "../s3-policy"
  s3_bucketName                 = local.change_owner == "1" ? join("", aws_s3_bucket.s3_bucket_change_owner[0].id) : join("", aws_s3_bucket.s3_bucket_keep_owner[0].id)
  kms_key_arn                   = var.kms_key_arn
  additional_policy_statements  = var.additional_policy_statements
  vpc_endpoint_ids              = var.vpc_endpoint_ids
  non_vpc_aws_service_roles_arn = concat([aws_iam_role.S3ReplicationRole.arn], var.non_vpc_aws_service_roles_arn)
}

resource "aws_s3_bucket_notification" "bucket_notification_existing_sns" {
  #flag
  count  = var.enabled && var.create_s3_notification && var.existing_sns_notification ? 1 : 0
  bucket = local.change_owner == "1" ? join("", aws_s3_bucket.s3_bucket_change_owner[0].id) : join("", aws_s3_bucket.s3_bucket_keep_owner[0].id)
  topic {
    topic_arn     = var.sns_topic_arn
    events        = var.sns_events
    filter_prefix = var.sns_filter_prefix
    filter_suffix = var.sns_filter_suffix
  }
}

resource "aws_s3_bucket_notification" "bucket_notification_new_sns" {
  #flag
  count  = var.enabled && var.create_s3_notification && var.create_sns_notification ? 1 : 0
  bucket = local.change_owner == "1" ? join("", aws_s3_bucket.s3_bucket_change_owner[0].id) : join("", aws_s3_bucket.s3_bucket_keep_owner[0].id)
  topic {
    topic_arn     = aws_sns_topic.s3-topic[0].arn
    events        = var.sns_events
    filter_prefix = var.sns_filter_prefix
    filter_suffix = var.sns_filter_suffix
  }
}

resource "aws_sns_topic" "s3-topic" {
  count  = var.enabled && var.create_s3_notification && var.create_sns_notification ? 1 : 0
  name   = var.sns_topic_name
  policy = <<POLICY
    {
      "Version":"2008-10-17",
      "Id": "SNS-S3Topic-Policy",
      "Statement":[
        {
          "Effect": "Allow",
          "Sid": "SNSPolicy",
          "Principal": {
              "Service": "s3.amazonaws.com"
              },
          "Action": "SNS:Publish",
          "Resource": ${jsonencode(var.sns_topic_resource)},
          "Condition":{
              "ArnLike":{"aws:SourceArn":"${local.change_owner == "1" ? join("", aws_s3_bucket.s3_bucket_change_owner[0].arn) : join("", aws_s3_bucket.s3_bucket_keep_owner[0].arn)}"}
          }
        },
        {
          "Effect": "Allow",
          "Sid": "SNSSubscribers",
          "Principal":{ "AWS": ${jsonencode(var.sns_topic_subscription_principal)}  },
          "Action": [
              "SNS:Subscribe",
              "SNS:Receive"
            ],
          "Resource": ${jsonencode(var.sns_topic_resource)}
        }
      ]
  }
  
POLICY

}

resource "aws_s3_bucket_notification" "bucket_notification_lambda" {
  count  = var.enabled && var.create_s3_notification && var.lambda_notification ? 1 : 0
  bucket = local.change_owner == "1" ? join("", aws_s3_bucket.s3_bucket_change_owner[0].id) : join("", aws_s3_bucket.s3_bucket_keep_owner[0].id)

  lambda_function {
    lambda_function_arn = var.lambda_function_arn
    events              = var.lambda_events
    filter_prefix       = var.lambda_filter_prefix
    filter_suffix       = var.lambda_filter_suffix
  }
}

#########################################################################################################################################
#Change owner is currently unsupported i.e. S3 replication using RTC can only be setup when source and target bucket are in same account
#########################################################################################################################################

resource "aws_s3_bucket" "s3_bucket_change_owner" {
  count         = var.enabled && local.change_owner == "1" ? 1 : 0
  bucket        = module.object_naming.object_name
  tags          = local.tags
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "co_versioning" {
  count  = var.enabled && local.change_owner == "1" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_change_owner[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "co_lifecycle" {
  count  = var.enabled && local.change_owner == "1" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_change_owner[0].id

  rule {
    id     = "transition"
    status = (0 < var.transition_days && var.transition_days < var.expiration_days) ? "Enabled" : "Disabled"

    transition {
      storage_class = coalesce(var.transition_class, "GLACIER")
      days          = var.transition_days != 0 ? var.transition_days : 999
    }
  }

  rule {
    id     = "noncurrent_version_transition"
    status = (0 < var.transition_days && var.transition_days < var.expiration_days) ? "Enabled" : "Disabled"

    noncurrent_version_transition {
      storage_class   = coalesce(var.transition_class, "GLACIER")
      noncurrent_days = var.transition_days != 0 ? var.transition_days : 999
    }
  }

  rule {
    id     = "expiration"
    status = "Enabled"

    expiration {
      days = var.expiration_days
    }
  }

  rule {
    id     = "object_delete_marker_expiration"
    status = "Enabled"

    expiration {
      expired_object_delete_marker = true #needs to be a separated rule from the main object expiry rule.
    }
  }

  rule {
    id     = "noncurrent_expiration"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort_incomplete_upload"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "co_encryption" {
  count  = var.enabled && local.change_owner == "1" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_change_owner[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_logging" "co_logging" {
  count  = var.enabled && local.change_owner == "1" ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket_change_owner[0].id

  target_bucket = data.aws_cloudformation_export.LogBucket-Name.value
  target_prefix = data.aws_cloudformation_export.LogBucket-Prefix.value
}

resource "aws_s3_bucket_public_access_block" "co_deny_public_access" {
  count                   = var.enabled && local.change_owner == "1" ? 1 : 0
  bucket                  = aws_s3_bucket.s3_bucket_change_owner[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}




##########################################
### Policy for SSM Access for Instance ###
##########################################
data "aws_iam_policy_document" "S3ReplicationPolicy" {
  statement {
    sid = "GetSourceReplication"
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [local.change_owner == "1" ? join("", aws_s3_bucket.s3_bucket_change_owner[0].arn) : join("", aws_s3_bucket.s3_bucket_keep_owner[0].arn)]
  }

  statement {
    sid = "GetSourceObjects"
    actions = [
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionForReplication",
    ]
    resources = ["${local.change_owner == "1" ? join("", aws_s3_bucket.s3_bucket_change_owner[0].arn) : join("", aws_s3_bucket.s3_bucket_keep_owner[0].arn)}/*"]
  }

  statement {
    sid = "ReplicateToTargetBucket"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:GetObjectVersionTagging",
      "s3:ObjectOwnerOverrideToBucketOwner",
    ]

    resources = ["${var.replication_target_arn}/*"] #tfsec:ignore:aws-iam-no-policy-wildcards
  }

  statement {
    sid = "EncryptOnTarget"
    actions = [
      "kms:Encrypt",
    ]
    resources = [var.replication_kms_key_id]
  }

  statement {
    sid = "DecryptOnSource"
    actions = [
      "kms:Decrypt",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "S3ReplicationRolePolicy" {
  name   = "${var.seal_id}-${var.deployment_id}-${var.environment}-S3Rep-${var.bucket_name}"
  policy = data.aws_iam_policy_document.S3ReplicationPolicy.json
}

resource "aws_iam_role" "S3ReplicationRole" {
  name                 = "${var.seal_id}-${var.deployment_id}-${var.environment}-S3Rle-${var.bucket_name}"
  permissions_boundary = var.iam_role_permission_boundary
  assume_role_policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
            "Service": "s3.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "S3ReplicationAttachment" {
  role       = aws_iam_role.S3ReplicationRole.name
  policy_arn = aws_iam_policy.S3ReplicationRolePolicy.arn
}





# /********************************** [BEGIN] GENERAL VARIABLES ***********************************/
variable "enabled" {
  description = "Defaults to true, can be set to false to disable resource creation for this module (since modules do not support the 'count' property)"
  type        = bool
  default     = true
}

variable "create_s3_notification" {
  description = "When set to true, will enable notifications for this S3 Bucket (e.g. either by SNS or Lambda)"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "The KMS Key to use for the encryption of this bucket.  Note: Encryption is Mandatory, not optional"
  type        = string
  default     = ""
}

variable "seal_id" {
  description = "SEAL id for Dynamo, used in the naming covention of the bucket"
  type        = string
  default     = ""
}

variable "deployment_id" {
  description = "Deployment ID for the Environment/Dynamo combination.  Used in the naming convention for the bucket"
  type        = string
  default     = ""
}

variable "use_guid" {
  description = "Determines whether a GUID should be used as part of the S3 Object Name"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "The name of the bucket that is being created"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment the object is deployed to.  Used as part of the object naming convention"
  type        = string
  default     = ""
}

variable "iam_role_permission_boundary" {
  description = "A permission boundary must be provided because the IAM create role will fail due to permission bonudary limitations"
  type        = string
}

# /********************************** [END] GENERAL VARIABLES *************************************/

# /********************************** [BEGIN] BASE S3 VARIABLES **********************************/
variable "tags" {
  description = "Expected tags for this object.  They are defaulted to 'UNKNOWN' to make it easy to identify tags on objects that need to be set."
  type        = map(string)
  default = {
    "fin.reg.chg.id"         = "UNKNOWN"
    "fin.res.scnd.id"        = "UNKNOWN"
    "fin.res.own.id"         = "UNKNOWN"
    "dev.res.for.id"         = "UNKNOWN"
    "sys.res.appcomponent"   = "UNKNOWN"
    "sys.res.env"            = "UNKNOWN"
    "sys.res.mon"            = "0"
    "dev.res.data.class"     = "UNKNOWN"
    "CORE_BACKUPS_RETENTION" = "NOBACKUP"
  }
}

# -------------------------------------- LIFECYCLE -----------------------------------------
variable "transition_days" {
  description = "The number of days before which you move the file to a different storage class"
  type        = number
  default     = 0
  # Set 0 to disable lifecycle
}

variable "transition_class" {
  description = "The storage class to move the bucket file to after the set number of days"
  type        = string
  default     = "GLACIER"
}

variable "expiration_days" {
  description = "The number of days before which the bucket contents expire"
  type        = number
}

variable "noncurrent_version_expiration_days" {
  description = "The number of days before which the non current versions of bucket objects expire"
  type        = number
  default     = 30
}

# -------------------------------------- LOGGING -----------------------------------------
variable "log_prefix" {
  description = "The prefix to use for Logs that are generated by this bucket in the Logging Bucket.  (E.g. S3 Access Logging)"
  type        = string
  default     = "core-LogBucket-Prefix"
}

variable "logbucket_name" {
  description = "The name of the log bucket to use for Logs that are generated by this bucket."
  type        = string
  default     = "core-LogBucket-Name"
}

# /********************************** [END] BASE S3 VARIABLES ************************************/
variable "additional_policy_statements" {
  type    = string
  default = ""
}

variable "vpc_endpoint_ids" {
  description = "VPC Endpoint ids to allow access to the S3 buckets"
  type        = list(string)
  default     = []
}

variable "non_vpc_aws_service_roles_arn" {
  description = "Roles ARN that will have access to the S3 buckets"
  type        = list(string)
  default     = []
}

# /********************************** [BEGIN] BASE SNS VARIABLES *********************************/

variable "sns_topic_arn" {
  description = "The SNS Topic to send a notification to when an S3 Event is triggered"
  type        = string
  default     = ""
}

variable "sns_topic_name" {
  description = "The SNS Topic Name to send a notification to when an S3 Event is triggered (used when the SNS Topic does not yet exist)"
  type        = string
  default     = ""
}

variable "create_sns_notification" {
  description = "When set to True and create_s3_notification = true, will send S3 Notification to SNS"
  type        = bool
  default     = false
}

variable "existing_sns_notification" {
  description = "Is set to true, then an existing SNS topic will be used, otherwise, a new SNS topic will be created"
  type        = bool
  default     = false
}

variable "sns_events" {
  description = "The type of s3 events that will cause an SNS notification to be triggered."
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
}

variable "sns_filter_prefix" {
  description = "If specified, will only forward the event to SNS is the object name begins with this text"
  type        = string
  default     = ""
}

variable "sns_filter_suffix" {
  description = "If specified, will only forward the event to SNS is the object name ends with this text"
  type        = string
  default     = ""
}

# -------------------------------------- SNS POLICY -----------------------------------------
variable "sns_topic_resource" {
  description = "Resources that can use the SNS Topic (if it is being created as part of the bucket creation)"
  type        = list(string)
  default     = []
}

variable "sns_topic_subscription_principal" {
  description = "Principals that can use the SNS topic (if it is being created as part of the bucket creation)"
  type        = list(string)
  default     = []
}

# /********************************** [END] BASE SNS PROPERTIES ***********************************/

# /********************************** [BEGIN] BASE LAMBDA VARIABLES *********************************/
variable "lambda_notification" {
  description = "If create_s3_notification = true, and this parameter is true, a Lambda event will be triggered when an S3 Event in this bucket is intercepted"
  type        = bool
  default     = false
}

variable "lambda_function_arn" {
  description = "The ARN of the Lambda function to call when an S3 Event is captured"
  type        = string
  default     = ""
}

variable "lambda_events" {
  description = "A list of events that will be sent to Lambda when captured"
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
}

variable "lambda_filter_prefix" {
  description = "When specified, only S3 Objects that begin with this text will cause an event to be triggered, and forwarded to the Lambda"
  type        = string
  default     = ""
}

variable "lambda_filter_suffix" {
  description = "When specified, only S3 Objects that end with this text will cause an event to be triggered, and forwarded to the Lambda"
  type        = string
  default     = ""
}

# /********************************** [END] LAMBDA VARIABLES ***********************************/

# -------------------------------------- REPLICATION -----------------------------------------
variable "replication_target_arn" {
  description = "The S3 ARN the bucket will replicate date to (note that this bucket should be created using the 's3-bucket-third-party' module"
  type        = string
  default     = ""
}

variable "replication_kms_key_id" {
  description = "The KMS Key ID in the replicated to account that will be used for replicated objects"
  type        = string
  default     = ""
}

variable "replication_target_account_id" {
  description = "The Account ID the bucket will be created in"
  type        = string
  default     = ""
}

variable "replication_target_force_original_owner" {
  description = "Determines whether the original object owner ID should be kept.  This can be used to keep the original owner, even if you are replicating to a different account"
  type        = string
  default     = "0"
}





