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




data "aws_eks_cluster" "eks-cluster" {
  name = local.cluster_name
}
# core-vault aurora
data "aws_iam_policy" "aurora_password_secret" {
  name = "${local.name_prefix}-replicadatabase-TMAuroraPasswordSecret"
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.eks-cluster.name
}




##################################################################
# Create IAM Role for TM vault rds init
###################################################################

data "aws_iam_policy_document" "assume_role_with_oidc" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:${var.operators_namespace}:${var.vault_rds_sa_name}"]
      variable = "${local.oidc_url}:sub"
    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "${local.oidc_url}:aud"
    }
  }
}

resource "aws_iam_role" "vault-rds-init-role" {
  name                 = local.vault_rds_init_role_name
  permissions_boundary = local.infradeployer_permission_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role_with_oidc.json
}

resource "aws_iam_role_policy_attachment" "vault_rds_init_role_aurora_password_secret" {
  policy_arn = data.aws_iam_policy.aurora_password_secret.arn
  role       = aws_iam_role.vault-rds-init-role.name
}





#####################################
# LOCAL VALUES
#####################################
locals {
  aws_assume_role                   = var.assume_role_format != "" ? format(var.assume_role_format, var.account_id, var.environment) : ""
  name_prefix                       = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}"
  cluster_name                      = "dn-${lower(var.environment)}-vault"
  oidc_url                          = replace(data.aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer, "https://", "")
  oidc_arn                          = format("arn:aws:iam::%s:oidc-provider/%s", var.account_id, local.oidc_url)
  infradeployer_permission_boundary = "arn:aws:iam::${var.account_id}:policy/pave/infradeployer/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER/permissions_boundary/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER-permissionBoundary"
  vault_rds_init_role_name          = "${local.name_prefix}-TMAuroraRdsInitRole"
}





#####################################
# MODULE
#####################################
module "sys_res_env" {
  source = "../modules/naming"

  environment = var.environment
}

module "naming" {
  source = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git?ref=v0.2.6"

  dev_res_for_id       = var.seal_id
  dyn_res_appname      = "tm_vault"
  dyn_res_appcomponent = "vault-aws-init"
  dyn_res_env          = var.environment
  fin_res_chg_id       = "313031"
  dyn_res_mon          = "1"
  sys_res_env          = module.sys_res_env.sys_res_env

}

module "add_oidc_to_sa" {
  source = "../modules/oidc"

  providers = {
    aws = aws
  }

  environment              = var.environment
  account_id               = var.account_id
  seal_id                  = var.seal_id
  deployment_id            = var.deployment_id
  serviceaccount_name      = var.serviceaccount_name
  serviceaccount_namespace = var.vault_namespace
  role_name                = "vault-installer"
  tags                     = module.naming.tags
}






output "role_id" {
  description = "The role's ID"
  value       = module.add_oidc_to_sa.role_id
}

output "role_arn" {
  description = "The ARN assigned by AWS to this role"
  value       = module.add_oidc_to_sa.role_arn
}

output "role_name" {
  description = "The name of the role"
  value       = module.add_oidc_to_sa.role_name
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

variable "account_id" {
  description = "The AWS Account ID to deploy the System Resources"
  type        = string
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

variable "vault_namespace" {
  type        = string
  description = "Vault Namespace in the cluster"
  default     = "105250-core-vault"
}

variable "serviceaccount_name" {
  type        = string
  description = "name of K8s service account to associate with IAM role"
  default     = "vault-installer-sa"
}

variable "operators_namespace" {
  description = "K8s namespace of the operators installation."
  type        = string
  default     = "105250-vault-operators"
}

variable "vault_rds_sa_name" {
  description = "K8s service account to associate with IAM role (rds init)"
  type        = string
  default     = "vault-rds-init-sa"
}

variable "assume_role_format" {
  description = "Format of the role that will be assumed. Might be set to null to use the current role (not assume)"
  type        = string
  default     = "arn:aws:iam::%s:role/pave/infradeployer/105250-EMEA-%s-INFRADEPLOYER"
}






#####################################
# CONFIGURATIONS
#####################################
terraform {
  required_version = ">= 1.0.7"
  required_providers {
    aws        = ">= 3.8.0"
    kubernetes = ">= 2.20.0"
  }

  # To run locally, init the backend with the following: tf init -backend-config=..\backends\LOCAL.tf
  backend "s3" {
    region  = "eu-west-1"
    encrypt = true
    key     = "tnn_core_vault/vault_aws_init.tfstate"
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = local.aws_assume_role
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks-cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks-cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}







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
      variable = "${local.kubernetes_oidc_url}:sub"
      values = [
        "system:serviceaccount:${var.serviceaccount_namespace}:${var.serviceaccount_name}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.kubernetes_oidc_url}:aud"
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




locals {
  cluster_name                  = var.vault_suffix_flag ? "dn-${lower(var.environment)}-vault" : "dn-${lower(var.environment)}"
  role_name                     = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}-${var.role_name}"
  role_permissions_boundary_arn = "arn:aws:iam::${var.account_id}:policy/pave/infradeployer/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER/permissions_boundary/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER-permissionBoundary"
  kubernetes_oidc_url           = replace(data.aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer, "https://", "")
  kubernetes_oidc_arn           = format("arn:aws:iam::%s:oidc-provider/%s", data.aws_caller_identity.current.account_id, local.kubernetes_oidc_url)
}

resource "aws_iam_role" "iam_role" {
  name                 = local.role_name
  path                 = "/"
  permissions_boundary = local.role_permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.assume_role_with_oidc.json
  tags                 = var.tags
}

resource "kubernetes_service_account" "irsa" {
  metadata {
    name      = var.serviceaccount_name
    namespace = var.serviceaccount_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.iam_role.arn
    }
  }
}










#Get VPC
data "aws_cloudformation_export" "vpc_id" {
  name = "core-Vpc01-Id"
}


resource "aws_route53_zone" "private" {
  name    = "vault-aurora.dynamo.${var.environment_url}.${var.region}.aws.jpmchase.net"
  comment = "Record for TM Vault Aurora RDS blue-green"

  vpc {
    vpc_id = data.aws_cloudformation_export.vpc_id.value
  }

  tags = (
    var.tags
  )
}

resource "aws_route53_record" "vault-aurora-blue-green" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "blue-green"
  type    = "CNAME"
  ttl     = 10

  weighted_routing_policy {
    weight = 100
  }
  set_identifier = "blue-green"
  records        = var.target == "blue" ? [var.blue_db] : [var.green_db]
}




#### Aurora Module

data "aws_region" "current" {
}

#Get VPC
data "aws_cloudformation_export" "vpc_id" {
  name = "core-Vpc01-Id"
}

data "aws_subnets" "vpc_private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_cloudformation_export.vpc_id.value]
  }
  filter {
    name = "tag:Name"
    values = [
      "PrivateSubnet*",
    ]
  }
}

data "aws_subnet" "subnets" {
  for_each = toset(data.aws_subnets.vpc_private_subnets.ids)
  id       = each.value
}


#icb-ledgers-vault-tools
resource "aws_iam_role_policy_attachment" "attach_password_policy_to_vault_tools_role" {
  role       = "${local.name_prefix}-vault-tools-role"
  policy_arn = aws_iam_policy.tm-db-password-secret-policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_logs_policy_to_vault_tools_role" {
  role       = "${local.name_prefix}-vault-tools-role"
  policy_arn = aws_iam_policy.tm_db_export_logs.arn
}


###############################
# Cloudwatch log group
###############################

resource "aws_cloudwatch_log_group" "cloudwatch_logs_exports" {
  name              = "/aws/rds/cluster/${var.parent_db_name}-cluster/postgresql"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.log_group_secret.arn

  tags = var.tags
}

data "aws_iam_policy_document" "aurora_logs_kms_policy" {
  statement {
    sid       = "Allow IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
      type        = "AWS"
    }
  }
  statement {
    sid    = "Allow Amazon Cloudwatch Log to use this key"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
    principals {
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
      type        = "Service"
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${var.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "log_group_secret" {
  description         = "Key for secret ${var.parent_db_name} log group"
  enable_key_rotation = true
  tags                = var.tags
  policy              = data.aws_iam_policy_document.aurora_logs_kms_policy.json
}


##############################################################
# Policy to export the metrics
##############################################################
resource "aws_iam_policy" "tm_db_export_logs" {
  name   = "${var.parent_db_name}-TMAuroraExportLogs"
  path   = local.policy_path
  policy = data.aws_iam_policy_document.aurora_logs_export_policy.json
}

data "aws_iam_policy_document" "aurora_logs_export_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateExportTask",
      "logs:CancelExportTask",
      "logs:DescribeExportTasks",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:GetLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.cloudwatch_logs_exports.arn}:*"
    ]
  }
}


##############################################################
# Enhanced monitoring
##############################################################
resource "aws_iam_role" "aurora_enhanced_monitoring" {
  name                 = "${var.parent_db_name}-enhanced-monitoring"
  assume_role_policy   = data.aws_iam_policy_document.aurora_enhanced_monitoring.json
  path                 = "/"
  permissions_boundary = "arn:aws:iam::${var.account_id}:policy/pave/infradeployer/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER/permissions_boundary/${var.seal_id}-EMEA-${var.environment}-INFRADEPLOYER-permissionBoundary"
  tags                 = var.tags
}

data "aws_iam_policy_document" "aurora_enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      identifiers = ["monitoring.rds.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy_attachment" "aurora_enhanced_monitoring" {
  role       = aws_iam_role.aurora_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}




locals {
  name_prefix = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}"
  policy_path = "/icbLedgers/"

  #Naming Convention
  backward_name = "${var.seal_id}-${var.backward_deployment_id}-${lower(var.environment)}-${var.db_name}"

  #Network
  subnet_ids_string = join(",", data.aws_subnets.vpc_private_subnets.ids)
  subnet_ids_list   = sort(split(",", local.subnet_ids_string))


  # Database settings and overrides
  cluster_identifier = "${var.parent_db_name}-cluster"
  db_port            = var.db_port

  # Database instance promotion tier
  promotion_tier_writer = 0
  promotion_tier_reader = 15

  # Detailed logging parameters
  detailed_logging_parameters = {
    log_error_verbosity      = "verbose"
    log_connections          = 1
    log_disconnections       = 1
    log_duration             = 1
    log_lock_waits           = 1
    log_replication_commands = 1
    log_rotation_size        = 1000000
    log_statement            = "all"
    # Highest supported severity by postgres DEBUG5
    log_min_messages        = "DEBUG1"
    log_min_error_statement = "DEBUG1"
  }

  # Notice logging parameters
  notice_logging_parameters = {
    log_min_messages        = "NOTICE"
    log_min_error_statement = "NOTICE"
  }

}

########################################################
# Database Pre-Requisites
########################################################
resource "aws_db_subnet_group" "default" {
  name       = "db-${local.backward_name}-cluster"
  subnet_ids = local.subnet_ids_list
}

resource "aws_rds_cluster_parameter_group" "tm_compliant" {
  name   = var.parent_db_name == "tm-vault-green" ? "${var.parent_db_name}-2" : "${var.parent_db_name}-1"
  family = var.db_parameter_cluster_group_family

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name         = "max_logical_replication_workers"
    value        = var.max_logical_replication_workers
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_worker_processes"
    value        = var.max_worker_processes
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_locks_per_transaction"
    value        = var.max_locks_per_transaction
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_pred_locks_per_transaction"
    value        = var.max_pred_locks_per_transaction
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_pred_locks_per_page"
    value        = var.max_pred_locks_per_page
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "password_encryption"
    value        = var.password_encryption
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_connections"
    value        = var.max_connections
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "rds.logical_replication"
    value        = var.logical_replication
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_wal_senders"
    value        = var.max_wal_senders
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_replication_slots"
    value        = var.max_replication_slots
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "timezone"
    value        = var.timezone
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "wal_buffers"
    value        = var.wal_buffers
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pgaudit,pg_stat_statements"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pgaudit,pg_stat_statements"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "wal_sender_timeout"
    value        = var.wal_sender_timeout
    apply_method = "immediate"
  }
  parameter {
    name         = "wal_receiver_timeout"
    value        = var.wal_receiver_timeout
    apply_method = "immediate"
  }
  dynamic "parameter" {
    for_each = var.detailed_logging ? local.detailed_logging_parameters : (var.notice_logging ? local.notice_logging_parameters : {})
    content {
      name  = parameter.key
      value = parameter.value
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster" "aurora_cluster" {
  depends_on         = [aws_cloudwatch_log_group.cloudwatch_logs_exports]
  cluster_identifier = local.cluster_identifier
  engine             = var.engine
  engine_version     = var.engine_version
  availability_zones = ["eu-west-1c", "eu-west-1b", "eu-west-1a"]

  # Parameters group
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.tm_compliant.name
  # Network / Security
  vpc_security_group_ids = [aws_security_group.db-security-group.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  # Backups / Snapshots
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = local.cluster_identifier
  apply_immediately           = true
  backup_retention_period     = var.db_backup_retention_period
  preferred_backup_window     = var.db_backup_window
  allow_major_version_upgrade = var.allow_major_version_upgrade
  snapshot_identifier         = var.snapshot_identifier

  storage_encrypted = "true"
  kms_key_id        = var.kms_key_id

  manage_master_user_password = true
  master_username             = "postgres"

  deletion_protection = var.db_deletion_protection
  tags = (
    var.tags
  )

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.lower_env ? [0] : []
    content {
      max_capacity = var.max_serverless_capacity
      min_capacity = 1
    }
  }

  #Monitoring
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
}

###############################
# 3. Create DB instances
###############################

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = length(var.availability_zones)
  identifier         = "${var.parent_db_name}-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id

  instance_class               = var.is_serverless ? "db.serverless" : (count.index == 0 ? var.high_promotion_tier_instance : var.lower_promotion_tier_instance)
  engine                       = aws_rds_cluster.aurora_cluster.engine
  engine_version               = aws_rds_cluster.aurora_cluster.engine_version
  availability_zone            = var.availability_zones[count.index]
  ca_cert_identifier           = var.ca_cert_identifier
  apply_immediately            = true
  promotion_tier               = count.index == 0 ? local.promotion_tier_writer : local.promotion_tier_reader
  performance_insights_enabled = true
  auto_minor_version_upgrade   = false

  # enhanced monitoring
  monitoring_interval = var.lower_env ? 0 : 15
  monitoring_role_arn = var.lower_env ? null : aws_iam_role.aurora_enhanced_monitoring.arn
}

###############################
# 3. DB snapshots monitoring
###############################
#Custom rule that trigger every Aurora snapshot and send event to logging.
#Needed for Grafana alerting for snapshots creation

resource "aws_cloudwatch_event_rule" "vault_aurora_backup" {
  name        = "${var.parent_db_name}-backup"
  description = "Monitor Aurora database backups for Vault"

  event_pattern = jsonencode({
    "source" : ["aws.rds"],
    "detail-type" : ["RDS DB Cluster Snapshot Event"],
    "detail" : {
      "EventCategories" : ["backup"],
      "SourceType" : ["CLUSTER_SNAPSHOT"],
      "Message" : ["Automated cluster snapshot created"],
      "SourceIdentifier" : [
        {
          "wildcard" : "rds:${var.parent_db_name}*"
        }
      ]
    }
  })
}

resource "aws_cloudwatch_log_group" "backup_cloudwatch_logs_exports" {
  name              = "/aws/events/${var.parent_db_name}/backup"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.log_group_secret.arn

  tags = (
    var.tags
  )
}

resource "aws_cloudwatch_event_target" "vault_aurora_backup" {
  rule = aws_cloudwatch_event_rule.vault_aurora_backup.name
  arn  = aws_cloudwatch_log_group.backup_cloudwatch_logs_exports.arn
}




output "rds_cluster_identifier" {
  value = aws_rds_cluster.aurora_cluster.cluster_identifier
}

output "rds_cluster_arn" {
  value = aws_rds_cluster.aurora_cluster.arn
}

output "rds_cluster_instance_arn" {
  value = aws_rds_cluster_instance.cluster_instances[*].arn
}
output "rds_cluster_instance_identifier" {
  value = aws_rds_cluster_instance.cluster_instances[*].identifier
}

output "rds_cluster_engine" {
  value = aws_rds_cluster.aurora_cluster.engine
}

output "rds_cluster_engine_version" {
  value = aws_rds_cluster.aurora_cluster.engine_version
}

output "rds_cluster_username" {
  value = aws_rds_cluster.aurora_cluster.master_username
}

output "rds_cluster_database_name" {
  value = aws_rds_cluster.aurora_cluster.database_name
}

output "rds_cluster_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}



##################################################################
# Policy for db secret password access
###################################################################
resource "aws_iam_policy" "tm-db-password-secret-policy" {
  name   = "${local.name_prefix}-${var.db_name}-TMAuroraPasswordSecret"
  path   = local.policy_path
  policy = data.aws_iam_policy_document.tm-db-password-secret.json
}

data "aws_iam_policy_document" "tm-db-password-secret" {
  statement {
    sid = "DbPasswordSecret"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    effect = "Allow"
    resources = [
      aws_rds_cluster.aurora_cluster.master_user_secret[0].secret_arn
    ]
  }
  statement {
    sid = "DbPasswordDecryption"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:kms:${data.aws_region.current.name}:${var.account_id}:key/${aws_rds_cluster.aurora_cluster.kms_key_id}"
    ]
  }

  statement {
    sid = "DbPasswordRdsDescribeClusters"
    actions = [
      "rds:DescribeDbClusters"
    ]
    effect = "Allow"
    resources = [
      aws_rds_cluster.aurora_cluster.arn
    ]
  }
}




########################################################
# Security Group
########################################################
resource "aws_security_group" "db-security-group" {
  name        = "${var.parent_db_name}-rds-group-cluster"
  description = "SG for ${var.parent_db_name} RDS database."
  vpc_id      = data.aws_cloudformation_export.vpc_id.value
  tags        = var.tags

  ingress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    description = "RDS Database ingress for ${var.parent_db_name}"
    cidr_blocks = [for s in data.aws_subnet.subnets : s.cidr_block]
  }
  egress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    description = "RDS Database egress for ${var.parent_db_name}"
    cidr_blocks = [for s in data.aws_subnet.subnets : s.cidr_block]
  }
}




terraform {
  required_version = ">=0.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.22.0"
    }
  }
}




####################################################################
# GENERAL Mandatory module variables
####################################################################
variable "environment" {
  description = "The environment to deploy to"
  type        = string
}

variable "seal_id" {
  description = "The SEAL ID for this deployment"
  type        = string
}

variable "deployment_id" {
  description = "The deloyment ID to use"
  type        = string
}

variable "backward_deployment_id" {
  description = "The deloyment ID to use for backward compatibility with old aurora terraforms"
  type        = string
  default     = "0000gb"
}

variable "skip_final_snapshot" {
  default = false
  type    = bool
}

variable "tags" {
  type = map(string)
}

###################################################################
# Mandatory RDS values for this module
###################################################################
variable "parent_db_name" {
  description = "The database name that this database will replicate"
  type        = string
}

variable "db_name" {
  description = "The name of the database replica that is being created"
  type        = string

}


#####################################################################
# PARENT values that can be overriden
#
# The following variable definitions will all default to the parent
# database definition unless implicitly overriden
#####################################################################
variable "db_port" {
  description = "The database port, if not specified will default to be the same as the parent database port"
  type        = string
  default     = "5432"
}

variable "high_promotion_tier_instance" {
  description = "The type of the instance you are created with the higher promotion tier."
  type        = string
}

variable "lower_promotion_tier_instance" {
  description = "The type of the instance you are created with the higher promotion tier."
  type        = string
}

variable "db_backup_window" {
  description = "The daily time range (in UTC) during which automated backups are created if they are enabled. Must not overlap with maintenance_window"
  type        = string
  default     = "03:30-04:30"
}

variable "db_backup_retention_period" {
  description = "The days to retain backups for. Must be between 0 and 35. Must be greater than 0 if the database is used as a source for a Read Replica"
  type        = number
  default     = 10
}

variable "db_deletion_protection" {
  description = "If the DB instance should have deletion protection enabled. The database can't be deleted when this value is set to true."
  type        = bool
  default     = true
}

variable "db_parameter_cluster_group_family" {
  description = "The family of the DB cluster parameter group."
  type        = string
}

##################
# SECRET MANAGER
##################
variable "engine" {
  type    = string
  default = "aurora-postgresql"
}

variable "engine_version" {
  type = string
}

variable "account_id" {
  description = "The AWS Account ID to deploy the System Key to"
  type        = string
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Set of log types to export to cloudwatch"
  type        = set(string)
  default     = null
}

variable "log_retention_in_days" {
  description = "Log retention in days for Aurora DB"
  type        = number
  default     = 7
}

variable "availability_zones" {
  description = "Set of availability_zone for aurora deployment"
  type        = list(string)
  default     = null
}

variable "max_locks_per_transaction" {
  description = "Set of max_locks_per_transaction for aurora deployment"
  type        = number
  default     = 2048
}

variable "max_pred_locks_per_transaction" {
  description = "Set of max_pred_locks_per_transaction for aurora deployment"
  type        = number
  default     = 2048
}

variable "max_pred_locks_per_page" {
  description = "Set of max_pred_locks_per_page for aurora deployment"
  type        = number
  # THUNDERBAL-161
  default = 256
}

variable "max_logical_replication_workers" {
  description = "Set of max_logical_replication_workers for aurora deployment"
  type        = number
  default     = 100
}

variable "max_worker_processes" {
  description = "Set of max_worker_processes for aurora deployment"
  type        = number
  default     = 200
}

variable "password_encryption" {
  description = "Set of password_encryption for aurora deployment"
  type        = string
  default     = "scram-sha-256"
}

variable "max_connections" {
  description = "Set of max_connections for aurora deployment"
  type        = number
  default     = 5000
}

variable "logical_replication" {
  description = "Set of rds.logical_replication for aurora deployment"
  type        = number
  default     = 1
}

variable "max_wal_senders" {
  description = "Set of max_wal_senders for aurora deployment"
  type        = number
  default     = 100
}

variable "max_replication_slots" {
  description = "Set of max_replication_slots for aurora deployment"
  type        = number
  default     = 100
}

variable "timezone" {
  description = "Set of timezone for aurora deployment"
  type        = string
  default     = "utc"
}

variable "kms_key_id" {
  description = "Kms key id to be used"
  type        = string
}

variable "max_serverless_capacity" {
  description = "max amount of ACU assigned to the cluster"
  type        = number
}

variable "lower_env" {
  description = "Except N, P all other environments are lower environment"
  type        = bool
}

variable "is_serverless" {
  description = "is it a provisioned or serverless instance"
  type        = bool
}

variable "ca_cert_identifier" {
  description = "Aurora DB CA certificate identifier"
  type        = string
}

variable "allow_major_version_upgrade" {
  description = "allows major version upgrade for cluster engine"
  type        = bool
}

variable "detailed_logging" {
  description = "Parameters group increased verbosity for debugging/auditing."
  type        = bool
  default     = false
}

variable "notice_logging" {
  description = "Parameters group increased log level for NOTICE. Use to get quire output to logs"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "snapshot identifier to restore from db"
  type        = string
  default     = null
}

variable "wal_receiver_timeout" {
  description = "Sets the maximum wait time to receive data from the sending server"
  type        = number
  default     = 0
}

variable "wal_sender_timeout" {
  description = "Sets the maximum time to wait for WAL replication"
  type        = string
  default     = 0
}

variable "logical_decoding_work_mem" {
  description = "This much memory can be used by each internal reorder buffer before spilling to disk"
  type        = string
  default     = 2147483647
}

variable "wal_buffers" {
  description = "Sets the number of disk-page buffers in shared memory for WAL."
  type        = string
  default     = -1
}

variable "logical_wal_cache" {
  description = "This much memory can be used by write-through cache. 0 - Disabled"
  type        = string
  default     = 262143
}






##### Nameing Module

locals {
  sys_res_env_map = {
    P = "PROD"
    E = "TEST"
    I = "TEST"
    N = "TEST"
    D = "DEV"
  }

  // https://confluence.dynamo.prd.aws.jpmchase.net/display/DIGPROJECT/AWS+Resources+Tagging+Standards
  // Environment Type
  sys_res_env = local.sys_res_env_map[upper(substr(var.environment, 0, 1))]
}



output "sys_res_env" {
  value = local.sys_res_env
}



terraform {
  required_version = ">= 0.12"
}



variable "environment" {
  description = "The environment to deploy to"
  type        = string
}



