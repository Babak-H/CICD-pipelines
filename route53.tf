#Set the code owners
* @@"Dynamo core engineering"




@Library('dynamo-shared-lib@v0.3.1848') _
def podTemplateYaml = libraryResource('terraform.yaml')

terraformBuild {
    kubernetesLabel = 'terraform.yaml'
    kubernetesYaml = podTemplateYaml

    terraformVersion = '1.0.7'

    // TODO enable tf validation for current directory
    // previous code terraformValidate() did not validate
    terraformValidate = false

    // Enable Sonar scanning
    sonarScan = true

    // Enable SSAP scanning
    ssapScan = true

    // Dynamo SEAL_ID for SSAP scanning
    sealId = '105250'

    pythonTests = false
    bitbucketCredentials = 'BB_CREDS'
}






## Introduction

This Terraform script allows an object(EC2/ALB/etc) to enable DNS entries in the JPMC domain. A master account with a Route 53 CloudFormation stack has been created to establish the necessary framework for this to happen.

You will not be able to see your DNS in route53 and it does not any parameters when run.

For more information please see https://bitbucketdc-cluster04.jpmchase.net/projects/CLOUDHERA/repos/xsphere/browse/docs/dns

## Usage

```hcl
terraform apply -var-file=terraform.tfvars
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| object_name | Name of the object | String | `` | yes |
| internal_name | internal dns name of object | String | `` | yes |
| domain_name | Name of domain for route53 ie [dev/uat/prod].aws.jpmchase.net, for beta accounts it should be awsbeta.jpmchase.net | String | `` | yes |
| dns_name | subdomain to append to domain | String | `` | yes | 
| zone_id | zone_id from the object(required if alias is true) | String | ``  | no |
| Alias |  whether this record should be an AWS Route 53 Alias(true/false) | String | ``  | yes |
| Type | A / CNAME (note A = A-RECORD) | String | ``  | yes |




data "aws_caller_identity" "current" {}




module "route53" {
  source = "../"

  object_name   = var.object_name
  internal_name = var.internal_name
  dns_name      = var.dns_name
  domain_name   = var.domain_name
  zone_id       = var.zone_id
  region        = var.region
  alias         = var.alias
  type          = var.type
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




region        = "eu-west-1"
object_name   = "dyn-test-com-1"
domain_name   = "dev.awsbeta.jpmchase.net"
dns_name      = "dnstest"
zone_id       = "Z35SXDOTRQ7X7K"
internal_name = "10.1.10.10"
type          = "A"
alias         = "false"




###################################
# GENERAL
###################################
variable "tags" {
  type        = map(string)
  description = "A map of additional tags"
  default     = {}
}

variable "internal_name" {
  type        = string
  description = "The Internal name to be used in the request"
}
variable "object_name" {
  type        = string
  description = ""
}

variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
}

variable "dns_name" {
  type        = string
  description = "The DNS name to associate with the Object <name>.<domain>"
}

variable "zone_id" {
  type        = string
  description = "The ID of the Amazon Route 53-hosted zone name that is associated with the load balancer."
  default     = ""
}

variable "domain_name" {
  type        = string
  description = "The hosted zone domain e.g. eng.awsdev.jpmchase.net"
}

variable "type" {
  type        = string
  description = "Type of route53 record, e.g. A, AAAA, CNAME"
}

variable "alias" {
  type        = bool
  description = "Whether this record should be an AWS Route 53 Alias"
}





#######################################
# Route 53
#######################################

locals {
  template_body = templatefile("${path.module}/register-route53.json", {
    region    = var.region,
    accountId = data.aws_caller_identity.current.account_id
  })
}


resource "aws_cloudformation_stack" "route53" {
  name = "${var.object_name}-route53"

  parameters = {
    InternalName      = var.internal_name
    Name              = var.dns_name
    AliasHostedZoneId = var.zone_id
    Domain            = var.domain_name
    Alias             = var.alias
    Type              = var.type
  }

  template_body = local.template_body
  tags          = var.tags
}





{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "Custom resource to register the wildcard DNS in Route 53 ",
  "Parameters": {
      "InternalName": {
          "Description": "The Internal name to be used in the request",
          "Type": "String"
      },
      "Name": {
          "Description": "The dns name to associate with the Object <name>.<domain>",
          "Type": "String"
      },
      "Domain": {
          "Description": "The hosted zone domain e.g. eng.awsdev.jpmchase.net",
          "Type": "String"
      },
      "AliasHostedZoneId": {
          "Description": "The ID of the Amazon Route 53-hosted zone name that is associated with the load balancer.",
          "Type": "String"
      },
      "Type": {
          "Description": "Type of route53 record",
          "Type": "String"
      },
      "Alias": {
          "Description": "(boolean): whether this record should be an AWS Route 53 Alias",
          "Type": "String"
      }
  },
  "Resources": {
      "UpdateRoute53": {
          "Type": "Custom::RegisterInRoute53",
          "Properties": {
              "ServiceToken": {
                  "Fn::Sub": "arn:aws:lambda:${region}:${accountId}:function:core-dns-DNSUpdateFunction"
              },
              "name": {
                  "Ref": "Name"
              },
              "value": {
                  "Ref": "InternalName"
              },
              "domain": {
                  "Ref": "Domain"
              },
              "alias": {
                  "Ref": "Alias"
              },
              "alias_hosted_zone_id": {
                  "Ref": "AliasHostedZoneId"
              },
              "type": {
                  "Ref": "Type"
              }
          }
      }
  },
  "Metadata": {
      "version": 1,
      "md5": "fdf3289a7859f19f0fcf66dad3e907eb"
  }
}




###################################
# GENERAL
###################################
variable "tags" {
  type        = map(string)
  description = "A map of additional tags"
  default     = {}
}

variable "internal_name" {
  type        = string
  description = "The Internal name to be used in the request"
}
variable "object_name" {
  type        = string
  description = ""
}

variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
}

variable "dns_name" {
  type        = string
  description = "The DNS name to associate with the Object <name>.<domain>"
}

variable "zone_id" {
  type        = string
  description = "The ID of the Amazon Route 53-hosted zone name that is associated with the load balancer."
  default     = ""
}

variable "domain_name" {
  type        = string
  description = "The hosted zone domain e.g. eng.awsdev.jpmchase.net"
}

variable "type" {
  type        = string
  description = "Type of route53 record, e.g. A, AAAA, CNAME"
}

variable "alias" {
  type        = bool
  description = "Whether this record should be an AWS Route 53 Alias"
}





version: 1.0
