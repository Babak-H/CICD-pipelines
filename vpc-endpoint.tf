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
