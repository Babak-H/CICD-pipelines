* @@"Dynamo Core Engineering"




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




# Changed the target file name to remove the leading directory (e.g. using basename)
data "archive_file" "lambda_source" {
  type        = "zip"
  source_file = var.filename
  output_path = "${path.module}/tmp/${basename(var.filename)}.zip"
}

#### Get Spoke VPC ID from datasource tag filter ####
data "aws_vpcs" "spoke_vpc" {
  count = var.use_vpc ? 1 : 0
  filter {
    name   = "tag:${var.vpc_default_tag_name}"
    values = [var.default_vpc_label]
  }
}

data "aws_vpc" "spoke_vpc_id" {
  count = var.use_vpc ? 1 : 0
  id    = element(data.aws_vpcs.spoke_vpc[0].ids, count.index)
}

data "aws_subnets" "vpc_subnets" {
  count = var.use_vpc ? 1 : 0
  filter {
    name   = data.aws_vpc.spoke_vpc_id[0].id
    values = [var.private_subnet == "true" ? var.private_subnet_pattern : var.public_subnet_pattern]
  }
}

data "aws_kms_key" "data_sys_key" {
  key_id = "alias/data-encryption/${var.environment}-DAT-SYS"
}





import json
import logging
import boto3
import os
import re
import warnings
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    logger.info('The inputs provided to CW event trigger: %s', event)
    time.sleep(310)
    logger.info('Sleeping for 5 minutes 10 secs to allow S3 VPC gatekeeper lambda to run and add the bucket to endpoint policy')
    rep_bucket_name = event['bucketname']
    logger.info('The bucket for which replication config needs to be set: %s', rep_bucket_name)
    detail = event['detail']
    res = s3_client.put_bucket_replication(Bucket=rep_bucket_name, ReplicationConfiguration=detail)
    logger.info('Replication rule config has been set per the inputs provided for the bucket: %s', rep_bucket_name)
    #check_bucket_tags(rep_bucket_name, detail)

    return

#def check_bucket_tags(rep_bucket_name, detail):

 #   response = s3_client.get_bucket_tagging(
  #      Bucket = rep_bucket_name
   # )
    #logger.info('the get tag bucket response is: %s', response)

    # for Tags in response['TagSet'][0]['Key']:
    #if response['TagSet'][0]['Key'] == 'ReplicationRule':
       # tag_value=response['TagSet'][0['Value']
     #   if response['TagSet'][0]['Value'] == 'true':
      #      logger.info('the detail is: %s', detail)
           # res = s3_client.put_bucket_replication(Bucket=rep_bucket_name, ReplicationConfiguration=detail)
            #logger.info('the put bucket response is: %s', res)

    #return




data "aws_kms_key" "sys_key" {
  key_id = "alias/data-encryption/${var.environment}-DAT-SYS"
}

module "test_lambda" {
  source        = "../"
  function_name = "S3ReplicationRuleSetup"
  filename      = "${path.module}/lambda/S3ReplicationRuleSetup.py"
  handler       = "S3ReplicationRuleSetup.lambda_handler"
  runtime       = var.runtime
  use_vpc       = "false"
  description   = "This Lambda sets up replication rule on S3 bucket"
  iam_role      = "arn:aws:lambda:eu-west-1:987705244904:function:105250-0000ie-dinfrc-s3replicationrulesetup"
  kms_key_arn   = data.aws_kms_key.sys_key.arn
  seal_id       = var.seal_id
  deployment_id = var.deployment_id
  environment   = var.environment
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
  region = "eu-west-1"
}




variable "environment" {
  description = "Short code for the environment"
  type        = string
  default     = "DINFRC"
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

variable "runtime" {
  description = "See Runtimes for valid values."
  type        = string
  default     = "python3.8"
}




locals {
  complete_subnets = [flatten(data.aws_subnets.vpc_subnets[*].ids)]
  empty_list       = []

  # Workaround for tf. v11.  It is not capable of doing a list comparison, so we need to compare strings, and then convert back to a list as required
  subnets = split(",", var.use_vpc == "true" ? join(",", local.complete_subnets) : join(",", local.empty_list))
}

module "lambda_naming" {
  source               = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git?ref=v1.0.110"
  friendly_name        = var.function_name
  use_guid             = var.use_guid
  environment          = var.environment
  seal_id              = var.seal_id
  deployment_id        = var.deployment_id
  fin_res_chg_id       = var.fin_res_chg_id
  dev_res_for_id       = var.dev_res_for_id
  sys_res_env          = var.sys_res_env
  dyn_res_env          = var.dyn_res_env
  dyn_res_mon          = var.dyn_res_mon
  dyn_res_appname      = var.dyn_res_appname
  dyn_res_appcomponent = var.dyn_res_appcomponent
  release_version      = var.release_version
  ami_build_id         = var.ami_build_id
  protected            = var.protected
  dyn_res_owner        = var.dyn_res_owner
  # DEPRECATED TAGS, please delete them from your code if using this module
  # For more info, check https://confluence.dynamo.prd.aws.jpmchase.net/display/CPE/AWS+Resources+Tagging+Standards
  # dev_res_data_class
  # sys_res_appcomponent
  # sys_res_appname
  # sys_res_mon
  # dyn_dep_owner
  # dyn_dep_method
}


resource "aws_lambda_function" "lambda" {
  #### General Configuration ###
  function_name = module.lambda_naming.object_name
  tags          = module.lambda_naming.tags
  description   = var.description
  environment {
    variables = var.environment_variables
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_config != null ? [var.dead_letter_config] : []

    content {
      target_arn = dead_letter_config.value
    }
  }

  publish = var.publish

  ### Source Code configuration ###
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256
  handler          = var.handler
  layers           = var.layers

  ### Runtime Environment ###
  runtime     = var.runtime
  memory_size = var.memory_size
  timeout     = var.timeout

  ### Security Environment ###
  kms_key_arn = var.kms_key_arn == "" ? data.aws_kms_key.data_sys_key.arn : var.kms_key_arn
  # Default to data-encryption/{ENV}-dat-sys if not specified....
  role = var.iam_role

  ### Network Configuration ###
  vpc_config {
    subnet_ids         = local.subnets
    security_group_ids = var.security_group_ids
  }
}







output "lambda_arn" {
  description = "Returns the Lambda ARN"
  value       = aws_lambda_function.lambda.arn
}

output "lambda_name" {
  description = "Returns the Lambda name"
  value       = aws_lambda_function.lambda.function_name
}

output "lambda_version" {
  description = "Returns the published Lambda version"
  value       = aws_lambda_function.lambda.version
}

output "lambda_invoke_arn" {
  description = "Returns the ARN to be used for invoking Lambda Function from API Gateway"
  value       = aws_lambda_function.lambda.invoke_arn
}




terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 1.0"
    }
  }
  required_version = ">= 0.13"
}





<a name="top"></a>

# Introduction
The Lambda module is a common module for creating Lambdas in AWS.  The following parameters are available when using this module:

# Index
View [Input Variables](#InputVars)
<br/>View [Output Variables](#OutputVars)
<br/>[How to use this Module](#Using)

<a name="InputVars"></a>
## Module Input Variables
### Common Variables

| Variable Name | Required | Description |
| --- | --- | --- |
| seal_id | <strong>Yes</strong> | The SEAL ID for the Lambda being deployed |
| deployment_id | <strong>Yes</strong> | The Deployment ID for the Lambda being deployed (e.g. 0000ie, 0000gb, 0000de) |
| environment | <strong>Yes</strong> | The Account ID for the Lambda being deployed (e.g. DCORE, DCOREPII) |
| use_guid | <strong>Yes</strong> | Whether a GUID should be appended to the Lambda name |

[Top](#Top)

### Lambda Specific Variables

| Variable Name | Required | Default Value | Description
| --- | --- | --- | --- |
| handler | <strong>Yes</strong> | | The Entry Point (function) that is used in the Lambda code.  If you have a python file called lambda_function.py, and it contains a handler with the definition `def lambda_hander(event, context)`, then the handler would be lambda_function.lambda_handler. |
| filename | <strong>Yes</strong> | | The name of the file containing the function code.  The location of the file should be made relative to your calling module using the `{module}` path syntax. |
| function_name | <strong>Yes</strong> | | The name of the function being created.  This will be combined with other variables to create the object name of the Lambda itself. |
| iam_role | <strong>Yes</strong> | | The IAM Role to be assigned to the Lambda, that grants permissions to the necessary modules |
| tag_owner | <strong>Yes</strong> | | Tag the lambda with the owner of the function
| tag_method | <strong>Yes</strong> | | Tag the lambda with the deployment method for the lambda
| use_vpc | No | true | Determines whether the Lambda will be VPC connected.  When set to false, VPC resources will not be available in the Lambda |
| runtime | No | python3.6 | The Runtime language to use for the Lambda function |
| description | No | <Empty String> | The Description of the Lambda |
| memory_size | No | 128 (MB) | The number of MB memory available to the Lambda |
| timeout | No | 300 (Seconds = 5 minutes) | The number of seconds the Lambda will execute before it is terminated by AWS |
| kms_key_arn | No | data-encryption/{environment}-DAT-SYS | The encryption key to use for Encrypting Lambda Storage (at rest).  This will default to the System Encryption key if none is specified |
| environment_variables | No | {none_set = ""} | A list of Environment variables to provide to the lambda.  If none are specified a single environment variable called "none_set" with an empty value will be created |
| dead_letter_config | No | | The ARN of the SNS Queue to notify when the Lambda execution fails. Defaults to None |
| layers | No | | A list of Lambda Layer ARNs.  Defaults to None. |
| publish | No | false | Whether to publish creation/change as new Lambda Function Version, needs to be `true` in order to set provisioned concurrency |

[Top](#Top)

### Networking Variables

<strong>None of these values need to be supplied if `use_vpc == "false"`.</strong>

| Variable Name | Required | Default Value | Description
| --- | --- | --- | --- |
| private_subnet | No | true | Determines whether the Lambda will be deployed to Private Subnets.  This is the default approach. |
| security_group_ids | No | empty | The security group IDs to be used when deploying the Lambda |
| default_vpc_label | No | "Spoke VPC" | The label used to identify the VPC used for deploying a Lambda |
| private_subnet_pattern | No | "PrivateSubnet*" | The text to use to identify a private subnet.  This defaults to everything beginning with "PrivateSubnet" |
| public_subnet_pattern | No | "PublicSubnet*" | The text to use to identify a public subnet.  This defaults to everything beginning with "PublicSubnet" |
| vpc_default_tag_name | No | "Name" | The tag name on the VPC that holds the text defined in `default_vpc_label` |
| subnet_default_tag_name | No | "Name" | The tag name on the Subnets that hold the text used by `private_subnet_pattern` and `public_subnet_pattern` |

[Top](#Top)

### Tag Variables

Plese check [AWS Resources Tagging Standards](https://confluence.dynamo.prd.aws.jpmchase.net/display/CPE/AWS+Resources+Tagging+Standards)

[Top](#Top)

<a name="OutputVars"></a>
## Module Output Variables
The following variables are exported by this module:

| Variable Name | Description |
| --- | --- |
| lambda_arn | The ARN of the Lamdba that has been created |
| lambda_name | The name of the Lambda that has been created |
| lambda_version | The version of the Lambda that has been published |

[Top](#Top)

<a name="Using"></a>
# Using the Module

## Example for a non-VPC connected Lambda:
````
############################
# Gatekeeper Lambda
############################
module "lambda_vpctos3gatekeeper_function" {
  source                = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/di/common-lambda.git"
  function_name         = "vpcTos3Gatekeeper"
  filename              = "${path.module}/lambda/VpcToS3Gatekeeper.py"
  handler               = "VpcToS3Gatekeeper.lambda_handler"
  runtime               = "${var.runtime}"
  description           = "This Lambda automatically adds S3 Buckets to the S3 Endpoint Whitelist"
  iam_role              = "${module.gatekeeper_iam_role.iam_role_arn}"
  kms_key_arn           = "${data.aws_kms_key.data_key.arn}"
  seal_id               = "${var.seal_id}"
  deployment_id         = "${var.deployment_id}"
  environment           = "${var.environment}"
  environment_variables = {
    PARAMETER_NAME      = "${module.create_whitelist.parameter_name}"
    BUCKET_PREFIX       = "${var.seal_id}-${var.deployment_id}"
  }
  use_vpc               = "false"

  # Set Tags
  sys_res_mon                 = "${var.sys_res_mon}"
  sys_res_appname             = "${var.sys_res_appname}"
  sys_res_appcomponent        = "${var.sys_res_appcomponent}"
  fin_res_own_id              = "${var.fin_res_own_id}"
  fin_res_scnd_id             = "${var.fin_res_scnd_id}"
  fin_res_chg_id              = "${var.fin_res_chg_id}"
  dev_res_data_class          = "${var.dev_res_data_class}"
}
````
[Top](#Top)

## Example of a VPC Connected Lambda
````
############################
# Rotation Function
############################
module "lambda_secretrotation_function" {
  source                 = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/di/common-lambda.git"
  function_name          = "secret-rotation-lambda"
  filename               = "${path.module}/lambda/secret-rotation-lambda.py"
  handler                = "secret-rotation-lambda.lambda_handler"
  runtime                = "${var.runtime}"
  layers                 = ["${aws_lambda_layer_version.layer_version.arn}"]
  description            = "Lambda for Secret Rotation"
  iam_role               = "${module.lambda_role.iam_role_arn}"
  kms_key_arn            = "${data.aws_kms_key.data_key.arn}"

  seal_id                = "${var.seal_id}"
  deployment_id          = "${var.deployment_id}"
  environment            = "${var.environment}"
  environment_variables  = {
    SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.region}.amazonaws.com"
  }
  security_group_ids     = ["${aws_security_group.sg.id}"]
  private_subnet         = "${var.private_subnet}"
}
````
[Top](#Top)


## Change Log


24/04/2020
- Updated tags to follow tagging approach (see here - https://confluence.dynamo.prd.aws.jpmchase.net/display/DIGPROJECT/Tagging+Approach)
- Added Jenkinsfile for automatic versioning

06/10/2021
- Removed deprecated tags from the object naming module but keeping the variables of those tags to reduce impact:
  - `dyn.dep.owner`
  - `dyn.dep.method`
  - `sys.res.appname`
  - `sys.res.appcomponent`
  - `sys.res.mon`
  - `dev.res.data.class`




################################################
# Business Settings
################################################
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

variable "environment" {
  description = "The environment we are running in"
  type        = string
  default     = ""
}

variable "use_guid" {
  description = "Whether to put a GUID at the end of the object name"
  type        = bool
  default     = false
}

################################################
# Lambda Specific Settings
################################################

variable "use_vpc" {
  description = "Whether to create this Lambda in a VPC"
  type        = string
  default     = "true"
}

variable "handler" {
  description = "The Entry Point for the package that is being deployed.  For Example, if you have a Python file called lamnda_function.py, and it constains a hanlder with the definition [def lambda_handler(event, context)] then the handler would be lambda_function.lambda_handler."
  type        = string
  default     = "lambda_handler"
}

variable "filename" {
  description = "The list of files that contain the code for the Lambda function(s)"
  type        = string
  default     = ""
}

variable "function_name" {
  description = "The name of the Lambda Function being created.  This will be integrated with the Standard Naming Convention used in Dynamo."
  type        = string
  default     = ""
}

variable "runtime" {
  description = "See Runtimes for valid values."
  type        = string
  default     = "python3.8"
}

variable "iam_role" {
  description = "The IAM role to be used by this Lambda function"
  type        = string
  default     = ""
}

variable "description" {
  description = "The Description of this Lambda"
  type        = string
  default     = ""
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime. Defaults to 128. See Limits"
  type        = string
  default     = "128"
}

variable "timeout" {
  description = "The amount of time your Lambda Function has to run in seconds. Defaults to 5 minutes. Maximum is 15 minutes."
  type        = string
  default     = "300"
}

variable "kms_key_arn" {
  description = "The ARN for the KMS encryption key.  This is mandatory."
  type        = string
  default     = ""
}

variable "environment_variables" {
  description = "Any environment variables being used by the Lambda"
  type        = map(any)
  default = {
    none_set = ""
  }
}

variable "dead_letter_config" {
  description = "The ARN of an SNS Queue to notify when the invocation fails"
  type        = string
  default     = null
}

variable "layers" {
  description = "List of Lambda Layer Version ARNs to attach to the Lambda Function (max of 5)"
  type        = list(string)
  default     = []
}

variable "publish" {
  description = "Whether to publish creation/change as new Lambda Function Version"
  type        = bool
  default     = false
}

################################################
# Networking
################################################
variable "private_subnet" {
  description = "Whether this is put into a Private Subnet or not"
  type        = string
  default     = "true"
}

variable "security_group_ids" {
  description = "When running in a VPC, this specifies the Subnet groups to use with the Lambda.  NOTE: If both subnet_id and security_group_id are unset, then the Lambda is not said to be VPC related / VPCs are not used."
  type        = list(string)
  default     = []
}

variable "default_vpc_label" {
  description = "The Label for the Main VPC to use for networking."
  type        = string
  default     = "Spoke VPC"
}

variable "private_subnet_pattern" {
  description = "Default Pattern for finding a Private Subnet"
  type        = string
  default     = "PrivateSubnet*"
}

variable "public_subnet_pattern" {
  description = "Default Pattern for finding a Private Subnet"
  type        = string
  default     = "PublicSubnet*"
}

variable "vpc_default_tag_name" {
  description = "Default Tag Name for Identifying a VPC Name"
  type        = string
  default     = "Name"
}

################################################
# Tag Elements
################################################
variable "fin_res_chg_id" {
  description = "Charge code for use by finance"
  type        = string
  default     = "313031"
}

variable "dev_res_for_id" {
  description = "Seal ID"
  type        = string
  default     = "UNKOWN"
}

variable "sys_res_env" {
  description = "Environment - DEV/TEST/PROD"
  type        = string
  default     = "UNKNOWN"
}

variable "dyn_res_env" {
  description = "Environment - D/E/I/N/P CORE,COREPII..."
  type        = string
  default     = "UNKNOWN"
}

variable "dyn_res_mon" {
  description = "Monitoring"
  type        = number
  default     = 1
}

variable "dyn_res_appname" {
  description = "Application Name"
  type        = string
  default     = "FUNCTION"
}

variable "dyn_res_appcomponent" {
  description = "Application Component"
  type        = string
  default     = "LAMBDA"
}

variable "dyn_res_owner" {
  type        = string
  description = "SQUAD"
  default     = "UNKNOWN"
}

variable "release_version" {
  description = "Release Version"
  type        = string
  default     = "UNKNOWN"
}

variable "ami_build_id" {
  description = "ID of AMI"
  type        = string
  default     = "UNKNOWN"
}

variable "protected" {
  description = "Cleaner Lambda"
  type        = string
  default     = "false"
}




version: 1.0
