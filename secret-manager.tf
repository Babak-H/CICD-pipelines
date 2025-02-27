## Resources

.

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




module "secret_rotation_false" {
  source = "../"

  description   = var.description
  environment   = var.environment
  kms_key_id    = data.aws_kms_key.secret_key.id
  region        = var.region
  secret_name   = var.secret_name
  secret_string = var.secret_string
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
