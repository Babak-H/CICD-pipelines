#Set the code owners
* @@"Dynamo core engineering"





@Library('dynamo-shared-lib') _
def podTemplateYaml = libraryResource('terraform.yaml')

terraformBuild {
    kubernetesLabel = 'terraform.yaml'
    kubernetesYaml = podTemplateYaml

    // Terraform version
    terraformVersion = '1.4.6'

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





<!-- BEGIN_TF_DOCS -->
## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name of the IAM role for EBS CSI driver to use | `string` | n/a | yes |
| <a name="input_iam_role_permission_boundary_arn"></a> [iam\_role\_permission\_boundary\_arn](#input\_iam\_role\_permission\_boundary\_arn) | n/a | `string` | n/a | yes |
| <a name="input_kubernetes_namespace"></a> [kubernetes\_namespace](#input\_kubernetes\_namespace) | The k8s namespace where EBS CSI driver is in | `string` | n/a | yes |
| <a name="input_kubernetes_oidc_arn"></a> [kubernetes\_oidc\_arn](#input\_kubernetes\_oidc\_arn) | arn of the OIDC provider of the EKS cluster that hosts EBS CSI driver | `string` | n/a | yes |
| <a name="input_kubernetes_oidc_url"></a> [kubernetes\_oidc\_url](#input\_kubernetes\_oidc\_url) | URL of the OIDC provider of the EKS cluster that hosts EBS CSI driver | `string` | n/a | yes |
| <a name="input_kubernetes_serviceaccount"></a> [kubernetes\_serviceaccount](#input\_kubernetes\_serviceaccount) | The k8s service account that EBS CSI driver uses | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_sa_iam_role_arn"></a> [sa\_iam\_role\_arn](#output\_sa\_iam\_role\_arn) | n/a |
<!-- END_TF_DOCS -->




resource "aws_iam_role" "ebs_csi_driver" {
  name                 = var.iam_role_name
  path                 = "/"
  permissions_boundary = var.iam_role_permission_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = var.kubernetes_oidc_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.kubernetes_oidc_url, "https://", "")}:sub" = "system:serviceaccount:${var.kubernetes_namespace}:${var.kubernetes_serviceaccount}"
            "${replace(var.kubernetes_oidc_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

data "aws_iam_policy" "ebs_csi_managed_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = data.aws_iam_policy.ebs_csi_managed_policy.arn
}

resource "aws_iam_role_policy" "ebs_csi_driver" {
  name   = "${var.iam_role_name}-kms-policy"
  role   = aws_iam_role.ebs_csi_driver.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ],
      "Resource": ["arn:aws:kms:eu-west-1:${var.aws_account_id}:key/*"],
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": ["arn:aws:kms:eu-west-1:${var.aws_account_id}:key/*"]
    }
  ]
}
EOF
}





output "sa_iam_role_arn" {
  value = aws_iam_role.ebs_csi_driver.arn
}





#!/usr/bin/env bash
LC_ALL=C

valid_branch_regex="^(bugfix|feature|hotfix|release)\/([a-zA-Z]+)+-[0-9]+"

message="Invalid branch name ($1)! The branch names in this project must adhere to this format: <bugfix|feature|hotfix|release>/<DYN-ID>.
         Rename your branch to a valid name and try again."

if [[ ! $1 =~ $valid_branch_regex ]]
then
    echo "$message"
    exit 1
fi

exit 0




#!/usr/bin/env bash
# imported from https://bitbucket.dynamo.prd.aws.jpmchase.net/projects/TFPAVE/repos/terraform-dynamo-aws-pave-iam/browse

set -euo pipefail
# Performs checks (format, validate, lint) on all terraform resources.
# Exits successfully if all resources pass all validations, with error if at least one fails.
#
# TF_VERSION: this is the terraform version that will be used to initialize and validate the modules.
# TF_SOURCE_PATH: this is the path to the terraform stacks source. Defaults to <project_root>/terraform/stacks

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TF_SOURCE_PATH=${TF_SOURCE_PATH:-"${root_dir}"}

# These paths are coupled to the bundles present in the docker image used by the template terraform.yaml.
# From terraform 13, the Terraform bundles are installed in /opt/terraform, and each bundle has a plugins directory.
TF_INSTALL_PATH=/opt/terraform/terraform${TF_VERSION}
TF_PLUGIN_DIR=${TF_PLUGIN_DIR:-${TF_INSTALL_PATH}/plugins}

function TERRAFORM() {
  ${TF_INSTALL_PATH}/terraform $@
}

function tf_fmt() {
  # TODO: need to install diffutils in image or use latest TF bundle?
  local directory=$1
  echo ">>> Running TF fmt on ${directory}"
  set +e
  formatted=$(TERRAFORM fmt -check -write=false -list -recursive ${directory})
  set -e
  if [ ! -z "${formatted}" ]; then
    echo -e "ERROR: TF fmt failed. The following files are NOT properly formatted:\n${formatted}\n"
    exit 1
  else
    echo "TF fmt ran successfully. All files are properly formatted"
  fi
}

function tf_validate() {
  TERRAFORM init -no-color -backend=false -input=false
  TERRAFORM validate
}

function tf_cleanup() {
  local tf_path=$1
  echo -e "\n-- Clean up ${tf_path}\n"
  for tf_folder in $(find "${tf_path}" -type d -name '.terraform'); do
    rm -rf ${tf_folder}
  done
}

###### TERRAFORM VALIDATION STARTS
echo '== Terraform Validation'
if [ ! -f "${TF_INSTALL_PATH}/terraform" ]; then
  echo "Terraform version '${TF_VERSION}' is not available"
  versions=($(ls /opt/terraform | grep terraform | sed -e "s/^terraform//"))
  echo "Available versions: ${versions[@]}"
fi
TERRAFORM --version

trap 'tf_cleanup "${TF_SOURCE_PATH}"' EXIT

# >>> RUN TFSEC
echo -e "\n>>> Running tfsec scan (this will temporarily NOT fail the pipeline even with detected problems)"
tfsec --soft-fail .
# ==================

# >>> RUN VALIDATE
echo -e "\n>>> Running tf-validate"
tf_validate
# ==================

# >>> RUN FORMAT
echo -e "\n>>> Running tf-format"
tf_fmt "${TF_SOURCE_PATH}"
# ==================

# >>> RUN LINT
echo -e "\n>>> Running tf-lint"
tflint
# ==================

# >>> RUN TFDOCS
echo -e "\n>>> Running terraform-docs"
terraform-docs --config .terraform-docs.yml --output-check .
# ==================

echo -e "\nValidation SUCCESSFUL"




variable "iam_role_name" {
  type        = string
  description = "Name of the IAM role for EBS CSI driver to use"
}

variable "kubernetes_oidc_url" {
  type        = string
  description = "URL of the OIDC provider of the EKS cluster that hosts EBS CSI driver"
}

variable "kubernetes_oidc_arn" {
  type        = string
  description = "arn of the OIDC provider of the EKS cluster that hosts EBS CSI driver"
}

variable "kubernetes_namespace" {
  type        = string
  description = "The k8s namespace where EBS CSI driver is in"
}

variable "kubernetes_serviceaccount" {
  type        = string
  description = "The k8s service account that EBS CSI driver uses"
}

variable "iam_role_permission_boundary_arn" {
  type        = string
  description = ""
}

variable "aws_account_id" {
  type        = string
  description = "ID of the AWS account that is calling the module, use data.aws_caller_identity.current.account_id"
}





version: 1.0
