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
```
