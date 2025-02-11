# Set the code owners
* @@"Dynamo core engineering"




@Library('dynamo-shared-lib') _
def podTemplateYaml = libraryResource('terraform.yaml')

terraformBuild {
    kubernetesLabel = 'terraform.yaml'
    kubernetesYaml = podTemplateYaml

    // Bitbucket credentials
    bitbucketCredentials = 'BB_CREDS'

    // Dynamo SEAL_ID for SSAP scanning
    sealId = '105250'

    terraformVersion = '1.0.7'

    // Enable Terraform validation
    terraformValidate = false

    // Enable Sonar scanning
    sonarScan = false

    // Enable SSAP scanning
    ssapScan = false

    // Enable Python Tests
    pythonTests = false   
}




# AWS Secrets Manager Module

Terraform module which creates a secret that will either be connected to the secret rotation lambda for secret rotation or create a secret that will not be connected to the rotation lambda depending on the postgres_password parameter input.

These types of resources are supported:

* [Secrets Manager Secret](https://www.terraform.io/docs/providers/aws/r/secretsmanager_secret.html)
* [Secrets Manager Secret Version](https://www.terraform.io/docs/providers/aws/r/secretsmanager_secret_version.html)


## Data Sources

The data source below pulls the name of the rotation lambda that will be used by the secret.
```hcl
data "aws_lambda_function" "lambda_rotation_name" {
  function_name = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}-secret-rotation-lambda"
}
```

The data source below pulls the name of the rotation lambda that will be used to force the rotation of the secret on creation so that the password in the state file is invalid.
```hcl
data "aws_lambda_function" "force_rotation_name" {
  function_name = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}-force-secret-rotation-lambda"
}
```

## Variables

region	-	(Required) The region that the resource is deployed to.

secret_name	-	(Required) The name for your secret. This will be integrated with the standard naming convention used in Dynamo.

secret_string	-	(Required) The data that you want to encrypt and store in Secrets Manager.

postgres_password	-	(Optional) True or false input only. The parameter is defaulted to false. If true, the secret will be connected to the rotation lambda. 

kms_key_id	-	(Required) The ID or alias for the KMS encryption key.

recovery_window_in_days - (Optional) The number of days that Secrets Manager waits before it can delete the secret. This value can be set to 0 to force deletion without recovery or range from 7 to 30 days. 

rotation_frequency	-	(Optional) This specifies the number of days between automatic scheduled rotations of the secret.

description	-	(Optional) The Description of the secret.

seal_id	-	(Required) SEAL ID for Dynamo.

environment	-	(Required) The environment we are running in.

deployment_id	-	(Required) Deployment ID for the Environment/Dynamo combination.

tags	-	(Required) Dynamo tags.

## Resources

The secret resource below will be created if the variable 'postgres_password' is set to true which will also be connected to the rotation lambda.

```hcl
resource "aws_secretsmanager_secret" "true_secret" {
  count                      = "${var.postgres_password ? 1 : 0}"

  name                       = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}-${var.secret_name}"
  description                = "${var.description}"
  kms_key_id                 = "${var.kms_key_id}"
  recovery_window_in_days    = "${var.recovery_window_in_days}"
  rotation_lambda_arn        = "${data.aws_lambda_function.lambda_rotation_name.arn}"
  rotation_rules          {
    automatically_after_days = "${var.rotation_frequency}"
  }
  tags                       = "${var.tags}"
}
```

The secret resource below will be created if the variable 'postgres_password' is false and it will not be connected to the rotation lambda. 

```hcl
resource "aws_secretsmanager_secret" "false_secret" {
  count                      = "${var.postgres_password ? 0 : 1}"

  name                       = "${var.secret_name}"
  description                = "${var.description}"
  kms_key_id                 = "${var.kms_key_id}"
  recovery_window_in_days    = "${var.recovery_window_in_days}"
  tags                       = "${var.tags}"
}
```

## Sample Usage

```hcl
module "secret" {
  source                        = "../secret-rotation-lambda/
  aws_region                    = "${var.region}"
  secret_name                   = "${var.secret_name}"
  
  secret_string                 = <<EOF
{
  "username": "${aws_db_instance.db.username}",
  "engine":   "${aws_db_instance.db.engine}",
  "dbname":   "${aws_db_instance.db.name}",
  "host":     "${aws_db_instance.db.address}",
  "password": "${aws_db_instance.db.password}",
  "port":     "${aws_db_instance.db.port}"
}
EOF

  postgres_password             = "${var.postgres_password}"
  kms_key_id                    = "${var.kms_key_id}"
  rotation_frequency			      = "${var.rotation_frequency}"
  recovery_window_in_days       = "${var.recovery_window_in_days}"
  description                   = "${var.description}"
  seal_id				                = "${var.seal_id}"
  deployment_id				          = "${var.deployment_id}"
  environment				            = "${var.environment}"
  tags				                  = "${var.tags}"
}
```


## Change Log

24/04/2020
- Updated tags to follow new tagging approach (see here - https://confluence.dynamo.prd.aws.jpmchase.net/display/DIGPROJECT/Tagging+Approach).

12/12/2023
- Upgraded module to TF v1.x




# Secrets Manager Module Example

Example configuration for Secrets Manager secret creation demonstrating creation of both secret types offered: those
rotated by Lambda and those not.

This module includes examples of the use of the following modules:

- terraform-dynamo-aws-com-object-naming




data "aws_kms_key" "secret_key" {
  key_id = "alias/data-encryption/${upper(var.environment)}-DAT-SYS"
}




module "secret_rotation_false" {
  source = "../"

  description   = var.description
  environment   = var.environment
  kms_key_id    = data.aws_kms_key.secret_key.id
  region        = var.region
  secret_name   = var.secret_name
  secret_string = var.secret_string
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
  region  = "eu-west-1"
}




variable "region" {
  type        = string
  description = "The region the resource is deployed to"
  default     = "eu-west-1"
}

variable "environment" {
  type        = string
  description = "The environment we are running in, e.g. DCORE, ISHS, EANALY"
  default     = "DCORE"
}

variable "description" {
  type        = string
  description = "The Description of this Secret"
  default     = "Example secret"
}

variable "use_guid" {
  type        = bool
  description = "Determines where a guid will be appended to the object name, default is true.  This is normally used when creating core objects that will be used across multiple sub-modules (e.g. to simlify referring to these objects by name)"
  default     = true
}

variable "secret_name" {
  type        = string
  description = "The name of the true Secret being created.  This will be integrated with the Standard Naming Convention used in ICB."
  default     = "example-secret"
}

variable "secret_string" {
  type        = string
  description = "The data that you want to encrypt and store in the secret."
  default     = "simple-example-secret-string"
}




#######################
# Get Rotation Lambda
#######################
data "aws_lambda_function" "lambda_rotation_name" {
  count         = var.postgres_password ? 1 : 0
  function_name = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}-secret-rotation-lambda"
}

############################
# Get Force Rotation Lambda
############################
data "aws_lambda_function" "force_rotation_name" {
  count         = var.postgres_password ? 1 : 0
  function_name = "${var.seal_id}-${var.deployment_id}-${lower(var.environment)}-force-secret-rotation-lambda"
}

################################
# Object naming
################################
module "object_naming" {
  source        = "git::https://bitbucket.dynamo.prd.aws.jpmchase.net/scm/terra/terraform-dynamo-aws-com-object-naming.git?ref=v1.0.102"
  friendly_name = var.secret_name
  use_guid      = var.use_guid
  environment   = var.environment
  seal_id       = var.seal_id
  deployment_id = var.deployment_id
}

##############################################################################
# Create and connect secret to rotation lambda if postgres_password is true.
##############################################################################
resource "aws_secretsmanager_secret" "true_secret" {
  count                   = var.postgres_password ? 1 : 0
  name                    = module.object_naming.object_name
  description             = var.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days
  rotation_lambda_arn     = data.aws_lambda_function.lambda_rotation_name[count.index].arn
  rotation_rules {
    automatically_after_days = var.rotation_frequency
  }
  tags = var.tags
}

#########################################################
# Create and store secret if postgres_password is false.
#########################################################
resource "aws_secretsmanager_secret" "false_secret" {
  count = var.postgres_password ? 0 : 1

  name                    = module.object_naming.object_name
  description             = var.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

#############################
# Create True Secret Value 
#############################
resource "aws_secretsmanager_secret_version" "true_version" {
  count = var.postgres_password ? 1 : 0

  lifecycle {
    ignore_changes = [
      secret_string
    ]
  }

  secret_id     = aws_secretsmanager_secret.true_secret[count.index].id
  secret_string = var.secret_string
}

############################# 
# Create False Secret Value 
#############################
resource "aws_secretsmanager_secret_version" "false_version" {
  count         = var.postgres_password ? 0 : 1
  secret_id     = aws_secretsmanager_secret.false_secret[count.index].id
  secret_string = var.secret_string

  lifecycle {
    ignore_changes = [
      secret_string
    ]
  }
}

data "aws_lambda_invocation" "rotate-secret" {
  count      = var.postgres_password && var.stage == "apply" ? 1 : 0
  depends_on = [aws_secretsmanager_secret_version.true_version]

  function_name = data.aws_lambda_function.force_rotation_name[count.index].function_name
  input         = <<JSON
  {
    "SecretId":           "${aws_secretsmanager_secret.true_secret[count.index].id}",
    "Step":               "rotate"
  }
  JSON
}





##################
# GENERAL
##################
variable "region" {
  type        = string
  description = "The region the resource is deployed to"
}

variable "description" {
  type        = string
  description = "The Description of this Secret"
}

variable "use_guid" {
  type        = bool
  description = "Determines where a guid will be appended to the object name, default is true.  This is normally used when creating core objects that will be used across multiple sub-modules (e.g. to simlify referring to these objects by name)"
  default     = true
}

##################
# SECRET MANAGER
##################
variable "secret_name" {
  type        = string
  description = "The name of the true Secret being created.  This will be integrated with the Standard Naming Convention used in ICB."
}

variable "rotation_frequency" {
  type        = number
  description = "This specifies the number of days between automatic scheduled rotations of the secret."
  default     = 28
}

variable "recovery_window_in_days" {
  type        = number
  description = "The number of days that AWS Secrets Manager waits before it can delete the secret. This value can be 0 to force deletion without recovery or range from 7 to 30 days."
  default     = 0
}

variable "kms_key_id" {
  type        = string
  description = "The ID or alias for the KMS encryption key."
}

variable "secret_string" {
  type        = string
  description = "The data that you want to encrypt and store in the secret."
}

variable "postgres_password" {
  type        = string
  description = "True or false input only. If true, the secret will be connected to the rotation lambda"
  default     = "false"
}

################################################
# Business Settings
################################################
variable "environment" {
  type        = string
  description = "The environment we are running in, e.g. DCORE, ISHS, EANALY"
}

variable "seal_id" {
  type        = string
  description = "SEAL id for ICB."
  default     = "105250"
}

variable "deployment_id" {
  type        = string
  description = "Deployment ID for the Environment/ICB combination."
  default     = "0000ie"
}

variable "tags" {
  type        = map(string)
  description = "ICB tags to apply to resources."
  default = {
    "fin.reg.chg.id"       = "313031"
    "dev.res.for.id"       = "UNKNOWN"
    "sys.res.appcomponent" = "SECRETS MANAGER"
    "dyn.res.appcomponent" = "SECRETS MANAGER"
    "sys.res.appname"      = "SECRET"
    "dyn.res.appname"      = "SECRET"
    "sys.res.env"          = "UNKNOWN"
    "dyn.res.env"          = "UNKNOWN"
    "sys.res.mon"          = "1"
    "dyn.res.mon"          = "1"
    "dev.res.data.class"   = "UNKNOWN"
    "release.version"      = "UNKNOWN"
    "protected"            = "false"
  }
}

variable "stage" {
  type        = string
  description = "Terraform stage that is currently executing, e.g. plan, apply"
  default     = ""
}





version: 1.0
