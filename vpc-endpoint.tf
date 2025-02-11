#Set the code owners
* @@"Dynamo core engineering"





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
09/08/2023

- Added Pre-commit hooks to validate Terraform code.
- Added Terraform validation scripts on the CI pipeline.
- Added example folder to test the Terraform code.
- Added CODEOWNERS file.
- Upgraded Terraform version to 1.0.7.

29/04/2020

- Added functionality to enable consumers of the module to pass through security groups with a new variable list external_sg_groups
- If This variable is passed it uses it, otherwise it defaults to the security group it creates.
- Also added a naming convention to enable the endpoint to be named using dyn_res_appname

24/04/2020
- Updated tags to follow new tagging approach (see here - https://confluence.dynamo.prd.aws.jpmchase.net/display/DIGPROJECT/Tagging+Approach).
- Created readme file for change log. 
- Executed 'terraform fmt' command for hygiene.
- Added 'null' Terraform provider to Jenkinsfile

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_core_resources"></a> [core\_resources](#module\_core\_resources) | git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-core-state.git | v1.0.3 |
| <a name="module_object_naming_security_group"></a> [object\_naming\_security\_group](#module\_object\_naming\_security\_group) | git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git | v1.0.108 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_build_id"></a> [ami\_build\_id](#input\_ami\_build\_id) | ID of the AMI | `string` | `"UNKNOWN"` | no |
| <a name="input_aws_service"></a> [aws\_service](#input\_aws\_service) | AWS Service for VPC endpoint | `string` | `""` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Deployment ID for environment into which the object is being deployed | `string` | `"0000gb"` | no |
| <a name="input_dev_res_for_id"></a> [dev\_res\_for\_id](#input\_dev\_res\_for\_id) | Seal ID | `string` | `"UNKNOWN"` | no |
| <a name="input_dyn_res_appcomponent"></a> [dyn\_res\_appcomponent](#input\_dyn\_res\_appcomponent) | Application Component | `string` | `"VPC ENDPOINT"` | no |
| <a name="input_dyn_res_appname"></a> [dyn\_res\_appname](#input\_dyn\_res\_appname) | Application Name | `string` | `"ENDPOINT"` | no |
| <a name="input_dyn_res_env"></a> [dyn\_res\_env](#input\_dyn\_res\_env) | Environment Type - D/E/I/N/P CORE,COREPII... | `string` | `"UNKNOWN"` | no |
| <a name="input_dyn_res_mon"></a> [dyn\_res\_mon](#input\_dyn\_res\_mon) | Monitoring | `number` | `1` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Simulates a count=0 for this module | `string` | `"true"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment the object is deployed to | `string` | `""` | no |
| <a name="input_external_sg_groups"></a> [external\_sg\_groups](#input\_external\_sg\_groups) | List Variable to pass in external Security groups to associate with VPC | `list(string)` | `[]` | no |
| <a name="input_fin_res_chg_id"></a> [fin\_res\_chg\_id](#input\_fin\_res\_chg\_id) | Charge code for use by finance | `string` | `"313031"` | no |
| <a name="input_friendly_name"></a> [friendly\_name](#input\_friendly\_name) | A friendly name that can be added to the object name | `string` | `""` | no |
| <a name="input_has_private_subnets"></a> [has\_private\_subnets](#input\_has\_private\_subnets) | Determines whether the VPC endpoint will use Private or Public Subnets. | `string` | `"true"` | no |
| <a name="input_is_privatelink"></a> [is\_privatelink](#input\_is\_privatelink) | Determines whether the VPC Endpoint being created is a PrivateLink endpoint. | `string` | `"false"` | no |
| <a name="input_protected"></a> [protected](#input\_protected) | This is an instance that should not be terminated | `string` | `"false"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region in which to deploy the resource | `string` | `"eu-west-2"` | no |
| <a name="input_release_version"></a> [release\_version](#input\_release\_version) | Release version of the code deployed | `string` | `"UNKNOWN"` | no |
| <a name="input_seal_id"></a> [seal\_id](#input\_seal\_id) | SEAL ID for the object being created | `string` | `"105250"` | no |
| <a name="input_sys_res_env"></a> [sys\_res\_env](#input\_sys\_res\_env) | Environment Type - DEV/TEST/PROD | `string` | `"UNKNOWN"` | no |
| <a name="input_tag_description"></a> [tag\_description](#input\_tag\_description) | VPC Endpoint tag description - Optional | `string` | `""` | no |
| <a name="input_use_guid"></a> [use\_guid](#input\_use\_guid) | Determines where a guid will be appended to the object name, default is true.  This is normally used when creating core objects that will be used across multiple sub-modules (e.g. to simlify referring to these objects by name) | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dns_entry"></a> [dns\_entry](#output\_dns\_entry) | Return 'dns\_entry' map, to get a value use for example: lookup(module.<module\_name>.dns\_entry[0], 'dns\_name') |
| <a name="output_id"></a> [id](#output\_id) | n/a |
<!-- END_TF_DOCS -->




<!-- BEGIN_TF_DOCS -->


## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_create_vpc_endpoint"></a> [create\_vpc\_endpoint](#module\_create\_vpc\_endpoint) | ../ | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_build_id"></a> [ami\_build\_id](#input\_ami\_build\_id) | ID of the AMI | `string` | `"UNKNOWN"` | no |
| <a name="input_aws_assume_role_pave"></a> [aws\_assume\_role\_pave](#input\_aws\_assume\_role\_pave) | SpinnakerManagedRolePave/infradeployer role to use | `string` | `"arn:aws:iam::084463983523:role/pave/infradeployer/106603-EMEA-DTOOL-INFRADEPLOYER"` | no |
| <a name="input_aws_service"></a> [aws\_service](#input\_aws\_service) | AWS Service for VPC endpoint | `string` | `""` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Deployment ID for environment into which the object is being deployed | `string` | `"0000gb"` | no |
| <a name="input_dev_res_data_class"></a> [dev\_res\_data\_class](#input\_dev\_res\_data\_class) | Data Classification | `string` | `"UNKNOWN"` | no |
| <a name="input_dev_res_for_id"></a> [dev\_res\_for\_id](#input\_dev\_res\_for\_id) | Seal ID | `string` | `"UNKNOWN"` | no |
| <a name="input_dyn_res_appcomponent"></a> [dyn\_res\_appcomponent](#input\_dyn\_res\_appcomponent) | Application Component | `string` | `"VPC ENDPOINT"` | no |
| <a name="input_dyn_res_appname"></a> [dyn\_res\_appname](#input\_dyn\_res\_appname) | Application Name | `string` | `"ENDPOINT"` | no |
| <a name="input_dyn_res_env"></a> [dyn\_res\_env](#input\_dyn\_res\_env) | Environment Type - D/E/I/N/P CORE,COREPII... | `string` | `"UNKNOWN"` | no |
| <a name="input_dyn_res_mon"></a> [dyn\_res\_mon](#input\_dyn\_res\_mon) | Monitoring | `number` | `1` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Simulates a count=0 for this module | `string` | `"true"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment the object is deployed to | `string` | `""` | no |
| <a name="input_external_sg_groups"></a> [external\_sg\_groups](#input\_external\_sg\_groups) | List Variable to pass in external Security groups to associate with VPC | `list(string)` | `[]` | no |
| <a name="input_fin_res_chg_id"></a> [fin\_res\_chg\_id](#input\_fin\_res\_chg\_id) | Charge code for use by finance | `string` | `"313031"` | no |
| <a name="input_friendly_name"></a> [friendly\_name](#input\_friendly\_name) | A friendly name that can be added to the object name | `string` | `""` | no |
| <a name="input_has_private_subnets"></a> [has\_private\_subnets](#input\_has\_private\_subnets) | Determines whether the VPC endpoint will use Private or Public Subnets. | `string` | `"true"` | no |
| <a name="input_is_privatelink"></a> [is\_privatelink](#input\_is\_privatelink) | Determines whether the VPC Endpoint being created is a PrivateLink endpoint. | `string` | `"false"` | no |
| <a name="input_protected"></a> [protected](#input\_protected) | This is an instance that should not be terminated | `string` | `"false"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region in which to deploy the resource | `string` | `"eu-west-2"` | no |
| <a name="input_release_version"></a> [release\_version](#input\_release\_version) | Release version of the code deployed | `string` | `"UNKNOWN"` | no |
| <a name="input_seal_id"></a> [seal\_id](#input\_seal\_id) | SEAL ID for the object being created | `string` | `"105250"` | no |
| <a name="input_sys_res_appcomponent"></a> [sys\_res\_appcomponent](#input\_sys\_res\_appcomponent) | Application Component | `string` | `"VPC ENDPOINT"` | no |
| <a name="input_sys_res_appname"></a> [sys\_res\_appname](#input\_sys\_res\_appname) | Application Name | `string` | `"ENDPOINT"` | no |
| <a name="input_sys_res_env"></a> [sys\_res\_env](#input\_sys\_res\_env) | Environment Type - DEV/TEST/PROD | `string` | `"UNKNOWN"` | no |
| <a name="input_sys_res_mon"></a> [sys\_res\_mon](#input\_sys\_res\_mon) | Monitoring | `number` | `1` | no |
| <a name="input_tag_description"></a> [tag\_description](#input\_tag\_description) | VPC Endpoint tag description - Optional | `string` | `""` | no |
| <a name="input_use_guid"></a> [use\_guid](#input\_use\_guid) | Determines where a guid will be appended to the object name, default is true.  This is normally used when creating core objects that will be used across multiple sub-modules (e.g. to simlify referring to these objects by name) | `bool` | `true` | no |
<!-- END_TF_DOCS -->




module "create_vpc_endpoint" {
  source              = "../"
  region              = var.region
  aws_service         = "com.amazonaws.${var.region}.vpce"
  seal_id             = var.seal_id
  deployment_id       = var.deployment_id
  use_guid            = var.use_guid
  environment         = "dshs"
  has_private_subnets = var.has_private_subnets
  is_privatelink      = var.is_privatelink
  enabled             = var.enabled
  external_sg_groups  = var.external_sg_groups
}




terraform {
  backend "s3" {
    bucket     = "106603-0000ie-DTOOL-terraform-state"
    key        = "test-s3-common-module/terraform.tfstate"
    kms_key_id = "arn:aws:kms:eu-west-1:003906622036:key/b23bc365-3df2-4622-832d-722ba85e3399"
    encrypt    = true
    region     = "eu-west-1"
    role_arn   = "arn:aws:iam::084463983523:role/pave/tfstatemanager/106603-EMEA-DTOOL-TFSTATEMANAGER"
  }
  required_version = ">= 1.0.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = var.aws_assume_role_pave
  }
}




variable "aws_assume_role_pave" {
  description = "SpinnakerManagedRolePave/infradeployer role to use"
  type        = string
  default     = "arn:aws:iam::084463983523:role/pave/infradeployer/106603-EMEA-DTOOL-INFRADEPLOYER"
}

variable "region" {
  description = "AWS Region in which to deploy the resource"
  type        = string
  default     = "eu-west-2"
}

variable "aws_service" {
  description = "AWS Service for VPC endpoint"
  type        = string
  default     = ""
}

variable "seal_id" {
  description = "SEAL ID for the object being created"
  type        = string
  default     = "105250"
}

variable "deployment_id" {
  description = "Deployment ID for environment into which the object is being deployed"
  type        = string
  default     = "0000gb"
}

variable "friendly_name" {
  description = "A friendly name that can be added to the object name"
  type        = string
  default     = ""
}

variable "use_guid" {
  description = "Determines where a guid will be appended to the object name, default is true.  This is normally used when creating core objects that will be used across multiple sub-modules (e.g. to simlify referring to these objects by name)"
  default     = true
}

variable "environment" {
  description = "Environment the object is deployed to"
  type        = string
  default     = ""
}

variable "has_private_subnets" {
  description = "Determines whether the VPC endpoint will use Private or Public Subnets."
  type        = string
  default     = "true"
}

variable "is_privatelink" {
  description = "Determines whether the VPC Endpoint being created is a PrivateLink endpoint."
  type        = string
  default     = "false"
}

variable "enabled" {
  description = "Simulates a count=0 for this module"
  type        = string
  default     = "true"
}

variable "external_sg_groups" {
  description = "List Variable to pass in external Security groups to associate with VPC"
  type        = list(string)
  default     = []
}

##-- Tagging Values --##
variable "fin_res_chg_id" {
  description = "Charge code for use by finance"
  default     = "313031"
}

variable "dev_res_for_id" {
  description = "Seal ID"
  default     = "UNKNOWN"
}

variable "sys_res_appcomponent" {
  description = "Application Component"
  default     = "VPC ENDPOINT"
}

variable "dyn_res_appcomponent" {
  description = "Application Component"
  default     = "VPC ENDPOINT"
}

variable "sys_res_appname" {
  description = "Application Name"
  default     = "ENDPOINT"
}

variable "dyn_res_appname" {
  description = "Application Name"
  default     = "ENDPOINT"
}

variable "sys_res_mon" {
  description = "Monitoring"
  default     = 1
}

variable "dyn_res_mon" {
  description = "Monitoring"
  default     = 1
}

variable "sys_res_env" {
  description = "Environment Type - DEV/TEST/PROD"
  default     = "UNKNOWN"
}

variable "dyn_res_env" {
  description = "Environment Type - D/E/I/N/P CORE,COREPII..."
  default     = "UNKNOWN"
}

variable "ami_build_id" {
  description = "ID of the AMI"
  default     = "UNKNOWN"
}

variable "protected" {
  description = "This is an instance that should not be terminated"
  default     = "false"
}

variable "release_version" {
  description = "Release version of the code deployed"
  default     = "UNKNOWN"
}

variable "dev_res_data_class" {
  description = "Data Classification"
  default     = "UNKNOWN"
}

variable "tag_description" {
  description = "VPC Endpoint tag description - Optional"
  type        = string
  default     = ""
}




##################################
# CREATE VPC ENDPOINT
##################################

locals {
  create_security_groups = split(",", aws_security_group.endpoint_security_group[0].id) ## We create this list from the string so that we can do a compare
}

locals {
  private_subnet_ids = join(",", flatten(module.core_resources.private_subnet_ids))
  public_subnet_ids  = join(",", flatten(module.core_resources.public_subnet_ids))
  split              = split(",", var.has_private_subnets == "true" ? local.private_subnet_ids : local.public_subnet_ids)
}

module "core_resources" {
  source              = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-core-state.git?ref=v1.0.3"
  has_private_subnets = var.has_private_subnets
}

# This is required to enable secrets manager Lambda rotation.
# This is not part of the initial XSphere or Core Pave.
resource "aws_vpc_endpoint" "Endpoint" {
  count               = var.enabled == "true" ? 1 : 0
  vpc_id              = module.core_resources.vpc_id
  service_name        = "com.amazonaws.${var.is_privatelink == "true" ? "vpce." : ""}${var.region}.${var.aws_service}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = split(",", var.has_private_subnets == "true" ? join(",", flatten(module.core_resources.private_subnet_ids)) : join(",", flatten(module.core_resources.public_subnet_ids)))
  private_dns_enabled = var.is_privatelink == "true" ? "false" : "true"
  security_group_ids  = split(",", length(var.external_sg_groups) >= 1 ? join(",", var.external_sg_groups) : join(",", local.create_security_groups))

  tags = {
    "technical.posture"    = var.has_private_subnets == "true" ? "private" : "public"
    "fin.res.chg.id"       = var.fin_res_chg_id
    "dev.res.for.id"       = var.dev_res_for_id
    "sys.res.env"          = var.sys_res_env
    "dyn.res.env"          = var.dyn_res_env
    "dyn.res.appcomponent" = var.dyn_res_appcomponent
    "dyn.res.appname"      = var.dyn_res_appname
    "dyn.res.mon"          = var.dyn_res_mon
    "ami.build.id"         = var.ami_build_id
    "release.version"      = var.release_version
    "protected"            = var.protected
    "Name"                 = "${var.dyn_res_appname}-endpoint"
    "Description"          = var.tag_description
  }
}

##################################################################
# Create Security group
##################################################################
module "object_naming_security_group" {
  source               = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git?ref=v1.0.108"
  friendly_name        = "${var.aws_service}-endpoint-sg"
  use_guid             = true
  environment          = var.environment
  seal_id              = var.seal_id
  deployment_id        = var.deployment_id
  fin_res_chg_id       = var.fin_res_chg_id
  dev_res_for_id       = var.dev_res_for_id
  sys_res_env          = var.sys_res_env
  dyn_res_env          = var.dyn_res_env
  dyn_res_appcomponent = var.dyn_res_appcomponent
  dyn_res_appname      = var.dyn_res_appname
  dyn_res_mon          = var.dyn_res_mon
  ami_build_id         = var.ami_build_id
  release_version      = var.release_version
  protected            = var.protected
}

data "aws_subnet" "vpc_subnets" {
  count = length(split(",", var.has_private_subnets == "true" ? join(",", flatten(module.core_resources.private_subnet_ids)) : join(",", flatten(module.core_resources.public_subnet_ids))))
  id    = var.has_private_subnets == "true" ? element(concat(flatten(module.core_resources.private_subnet_ids), [""]), count.index) : element(concat(flatten(module.core_resources.public_subnet_ids), [""]), count.index)
}

resource "aws_security_group" "endpoint_security_group" {
  count       = var.enabled == "true" ? 1 : 0
  name        = module.object_naming_security_group.object_name
  description = "endpoint-security-group for ${var.aws_service}"
  vpc_id      = module.core_resources.vpc_id

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [for s in data.aws_subnet.vpc_subnets : s.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.object_naming_security_group.tags
}





output "id" {
  value = aws_vpc_endpoint.Endpoint.*.id[0]
}

output "dns_entry" {
  description = "Return 'dns_entry' map, to get a value use for example: lookup(module.<module_name>.dns_entry[0], 'dns_name')"
  value       = aws_vpc_endpoint.Endpoint.*.dns_entry[0]
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




formatter: markdown table

version: ""

#header-from: ""
#footer-from: ""

recursive:
  enabled: true
  path: .

output:
  file: "README.md"
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->

sections:
  show:
#    - header
    - inputs
    - outputs
    - providers
    - modules
#    - footer

sort:
  enabled: true
  by: name

settings:
  anchor: true
  color: true
  default: true
  description: false
  escape: true
  hide-empty: true
  html: true
  indent: 2
  lockfile: true
  read-comments: true
  required: true
  sensitive: true
  type: true




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
terraform-docs --config ./scripts/terraform-docs.yml .
# ==================

echo -e "\nValidation SUCCESSFUL"




version: 1.0




terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}




variable "region" {
  description = "AWS Region in which to deploy the resource"
  type        = string
  default     = "eu-west-2"
}

variable "aws_service" {
  description = "AWS Service for VPC endpoint"
  type        = string
  default     = ""
}

variable "seal_id" {
  description = "SEAL ID for the object being created"
  type        = string
  default     = "105250"
}

variable "deployment_id" {
  description = "Deployment ID for environment into which the object is being deployed"
  type        = string
  default     = "0000gb"
}

variable "friendly_name" {
  description = "A friendly name that can be added to the object name"
  type        = string
  default     = ""
}

variable "use_guid" {
  description = "Determines where a guid will be appended to the object name, default is true.  This is normally used when creating core objects that will be used across multiple sub-modules (e.g. to simlify referring to these objects by name)"
  default     = true
}

variable "environment" {
  description = "Environment the object is deployed to"
  type        = string
  default     = ""
}

variable "has_private_subnets" {
  description = "Determines whether the VPC endpoint will use Private or Public Subnets."
  type        = string
  default     = "true"
}

variable "is_privatelink" {
  description = "Determines whether the VPC Endpoint being created is a PrivateLink endpoint."
  type        = string
  default     = "false"
}

variable "enabled" {
  description = "Simulates a count=0 for this module"
  type        = string
  default     = "true"
}

variable "external_sg_groups" {
  description = "List Variable to pass in external Security groups to associate with VPC"
  type        = list(string)
  default     = []
}

##-- Tagging Values --##
variable "fin_res_chg_id" {
  description = "Charge code for use by finance"
  default     = "313031"
}

variable "dev_res_for_id" {
  description = "Seal ID"
  default     = "UNKNOWN"
}

variable "dyn_res_appcomponent" {
  description = "Application Component"
  default     = "VPC ENDPOINT"
}

variable "dyn_res_appname" {
  description = "Application Name"
  default     = "ENDPOINT"
}

variable "dyn_res_mon" {
  description = "Monitoring"
  default     = 1
}

variable "sys_res_env" {
  description = "Environment Type - DEV/TEST/PROD"
  default     = "UNKNOWN"
}

variable "dyn_res_env" {
  description = "Environment Type - D/E/I/N/P CORE,COREPII..."
  default     = "UNKNOWN"
}

variable "ami_build_id" {
  description = "ID of the AMI"
  default     = "UNKNOWN"
}

variable "protected" {
  description = "This is an instance that should not be terminated"
  default     = "false"
}

variable "release_version" {
  description = "Release version of the code deployed"
  default     = "UNKNOWN"
}

variable "tag_description" {
  description = "VPC Endpoint tag description - Optional"
  type        = string
  default     = ""
}





version: 1.0
