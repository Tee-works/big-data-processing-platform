locals {
  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# VPC
module "vpc" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/vpc?ref=v1.0.1"

  cidr_block           = var.cidr_block
  vpc_name             = var.vpc_name
  create_igw           = true
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, {
    Name = "${var.project_name}-vpc"
    }
  )
}

# Subnets for target vpn
module "vpn_target_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.0.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  subnet_name             = "${module.vpc.vpc_name}-public-a"
  route_table_id          = module.vpc.public_route_table_id
  tags                    = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-public-a"
    }
  )
}

# Second public subnet
module "vpc_public_b_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.1.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  subnet_name             = "${module.vpc.vpc_name}-public-b"
  route_table_id          = module.vpc.public_route_table_id
  tags                    = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-public-b"
    }
  )
}

# private subnet
module "vpc_private_a_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.3.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  subnet_name             = "${module.vpc.vpc_name}-private-a"
  route_table_id          = module.vpc.private_route_table_id
  tags                    = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-private-a"
    }
  )
}

# second private subnet
module "vpc_private_b_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.4.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false
  subnet_name             = "${module.vpc.vpc_name}-private-b"
  route_table_id          = module.vpc.private_route_table_id
  tags                    = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-private-b"
    }
  )
}
# importing generated server certificate 
resource "aws_acm_certificate" "server_certificate" {
  private_key       = file("certificates/vpn.example.com.key")
  certificate_body  = file("certificates/vpn.example.com.crt")
  certificate_chain = file("certificates/ca.crt")

  tags = merge(local.tags, {
    Name = "${var.project_name}-server-cert"
    }
  )
}

# importing generated client certificate
resource "aws_acm_certificate" "client_certificate" {
  private_key       = file("certificates/client1.domain.tld.key")
  certificate_body  = file("certificates/client1.domain.tld.crt")
  certificate_chain = file("certificates/ca.crt")

  tags = merge(local.tags, {
    Name = "${var.project_name}-client-cert"
    }
  )
}

# creating vpn endpoint
resource "aws_ec2_client_vpn_endpoint" "client_vpn" {
  description            = "BuildItAll client VPN"
  server_certificate_arn = aws_acm_certificate.server_certificate.arn
  client_cidr_block      = "10.0.0.0/16"
  split_tunnel           = true
  vpc_id                 = module.vpc.vpc_id
  security_group_ids     = [module.vpn_target_subnet_sg.security_group_id]
  client_login_banner_options {
    banner_text = "Welcome to the BuildItAll VPN"
    enabled     = true
  }


  tags = merge(local.tags, {
    Name = "${var.project_name}-client-vpn"
    }
  )

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_certificate.arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.logs.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.log_stream.name
  }
}

# Creating a client VPN network association
resource "aws_ec2_client_vpn_network_association" "aws_ec2_client_vpn_network_association" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn.id
  subnet_id              = module.vpn_target_subnet.subnet_id

}

# Creating a client VPN authorization rule
resource "aws_ec2_client_vpn_authorization_rule" "client_vpn_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn.id
  target_network_cidr    = var.cidr_block
  authorize_all_groups   = true
  description            = "Allow access to all groups"
}

# Creating a client VPN security group
module "vpn_target_subnet_sg" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/security?ref=v1.0.0"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${module.vpc.vpc_name}-vpn-target-subnet-sg"
  description         = "Allow  all protocols outbound traffic and HTTPS inbound traffic only from cidr range"

  ingress_rules = {
    https = {
      cidr_ipv4   = "10.0.0.0/16"
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "Allow HTTPS from VPN client"
    },
  }
  egress_rules = {
    all = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpn-target-subnet-sg"
    }
  )
}


# Security Groups for public and private subnets
module "vpc_public_sg" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/security?ref=v1.0.0"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${module.vpc.vpc_name}-public-sg"
  description         = "Allow HTTPS inbound traffic only from cidr range and all protocols outbound traffic"

  ingress_rules = {
    https = {
      cidr_ipv4   = var.cidr_block
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "Allow HTTPS from ${var.cidr_block}"
    },

    http = {
      cidr_ipv4   = var.cidr_block
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "Allow HTTP from ${var.cidr_block}"
    }

    ssh = {
      cidr_ipv4   = var.cidr_block
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      description = "Allow ssh from ${var.cidr_block}"
    }
  }

  egress_rules = {
    all = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

  tags = local.tags
}

module "vpc_private_sg" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/security?ref=v1.0.0"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${module.vpc.vpc_name}-private-sg"
  description         = "Allow all traffic from  VPC"

  ingress_rules = {
    vpc_a = {
      cidr_ipv4   = var.cidr_block
      ip_protocol = "-1"
      description = "Allow all protocol from VPC"
    }
  }

  egress_rules = {
    all = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

  tags = local.tags
}

# Gateway Endpoint

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    module.vpc.private_route_table_id
  ]
  tags = merge(local.tags, {
    Name = "${var.project_name}-s3-gateway-endpoint"
    }
  )
}
# Interface Endpoints
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  security_group_ids  = [module.vpc_private_sg.security_group_id]
  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-logs-interface-endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  security_group_ids  = [module.vpc_private_sg.security_group_id]
  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-sm-interface-endpoint"
    }
  )
}


# IAM 
resource "aws_iam_group" "group" {
  name = var.group_name


}
# Creating IAM users and attaching them to the group
resource "aws_iam_user" "users" {
  for_each = toset(var.users)

  name = each.value


  tags = merge(local.tags, {
    Name = "${var.project_name}-iam-users"
    }
  )
}


resource "aws_iam_user_group_membership" "users_to_group" {
  for_each = toset(var.users)

  user   = aws_iam_user.users[each.value].name
  groups = [aws_iam_group.group.name]

}

# Creating IAM login profile for users
resource "aws_iam_user_login_profile" "users" {
  for_each = toset(var.users)

  user                    = aws_iam_user.users[each.value].name
  password_length         = var.password_length
  password_reset_required = var.password_reset_required

}

# Creating IAM access keys for users
resource "aws_iam_access_key" "users" {
  for_each = var.create_access_keys ? toset(var.users) : []

  user = aws_iam_user.users[each.value].name
}

# Creating IAM policy for the group
resource "aws_iam_policy" "combined_policy" {
  name        = "${var.group_name}-CombinedPolicy"
  description = "policy for ${var.group_name} with read access to services"


  policy = templatefile("./policies/policy.json", {
    s3_bucket_arn  = module.s3_bucket.bucket_arn
    s3_object_arns = ["${module.s3_bucket.bucket_arn}/*"]
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.logs.arn
    mwaa_arn = aws_mwaa_environment.big_data.arn


  })
}

# # Attach the policy to the group
resource "aws_iam_group_policy_attachment" "policy_attachment" {
  group      = aws_iam_group.group.name
  policy_arn = aws_iam_policy.combined_policy.arn

}

# # Secret Managers
resource "aws_secretsmanager_secret" "security_manager" {
  name = "${var.project_name}-security-manager7"

  tags                           = local.tags
  description                    = "Secret manager for ${var.project_name} project"
  force_overwrite_replica_secret = true


}

# # Secret Manager version
resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id = aws_secretsmanager_secret.security_manager.id
  secret_string = jsonencode({
    "MAIL_SERVER"   = var.mail_server,
    "MAIL_PORT"     = var.mail_port,
    "MAIL_USERNAME" = var.mail_username,
    "MAIL_PASSWORD" = var.mail_password,
    "MAIL_USE_TLS"  = var.mail_use_tls,
  })
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "logs" {
  name              = "/big_data/${var.project_name}"
  retention_in_days = 30

  tags = merge(local.tags, {
    Name = "${var.project_name}-cloudwatch-logs"
    }
  )
}

# CloudWatch Log Stream
resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "Client_VPN-stream"
  log_group_name = aws_cloudwatch_log_group.logs.name
}

# S3

module "s3_bucket" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/s3?ref=v1.0.3"

  bucket_name = var.aws_bucket_name

  enable_versioning = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-s3"
    }
  )
}

# mwa execution role
resource "aws_iam_role" "mwaa_execution_role" {
  name = "${var.project_name}-mwaa-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = [
            "airflow.amazonaws.com",
            "airflow-env.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.project_name}-mwaa-role"
    }
  )
}

# Create EMR Service Role
resource "aws_iam_role" "emr_service_role" {
  name = "EMR_DefaultRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

# # Attach EMR service managed policy
resource "aws_iam_role_policy_attachment" "emr_service_role_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

# # Attach EMR EC2 instance profile managed policy
resource "aws_iam_policy" "emr_service_additional_policy" {
  name        = "EMR_ServiceAdditionalPermissions"
  description = "Additional permissions for EMR service role to create EC2 resources"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:*",
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "iam:CreateServiceLinkedRole",
        Resource = "*",
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "spot.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.tags
}

# # Attach the additional policy to EMR service role
resource "aws_iam_role_policy_attachment" "emr_service_additional_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = aws_iam_policy.emr_service_additional_policy.arn
}

# Create EMR Instance Profile Role 
resource "aws_iam_role" "emr_ec2_role" {
  name = "EMR_EC2_DefaultRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

# Attach EMR EC2 instance profile managed policy
resource "aws_iam_role_policy_attachment" "emr_ec2_role_attachment" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Create IAM instance profile for EMR EC2 instances
resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
  name = "EMR_EC2_DefaultRole"
  role = aws_iam_role.emr_ec2_role.name
}

# mwa customer managed policy
resource "aws_iam_policy" "mwaa_policy" {
  name        = "${var.project_name}-mwaa-policy"
  description = "Permissions for MWAA to access S3, CloudWatch, EMR, and Secrets Manager"

  policy = templatefile("./policies/mwaa-policy.json", {
    s3_arn       = module.s3_bucket.bucket_arn
    secret_arn   = aws_secretsmanager_secret.security_manager.arn
    emr_role_arn = aws_iam_role.emr_service_role.arn,
    emr_ec2_arn  = aws_iam_role.emr_ec2_role.arn

  })
}

# Attach the MWAA policy to the execution role
resource "aws_iam_role_policy_attachment" "mwaa_policy_attachment" {
  role       = aws_iam_role.mwaa_execution_role.name
  policy_arn = aws_iam_policy.mwaa_policy.arn
}


# MWAA Environment
resource "aws_mwaa_environment" "big_data" {
  name                   = "${var.project_name}-mwaa"
  execution_role_arn     = aws_iam_role.mwaa_execution_role.arn
  dag_s3_path            = "dags/"
  source_bucket_arn      = module.s3_bucket.bucket_arn
  environment_class      = "mw1.small"
  startup_script_s3_path = "scripts/mwaa_startup.sh"
  webserver_access_mode  = "PRIVATE_ONLY"


  airflow_configuration_options = {
    "email.email_backend"            = "airflow.providers.smtp.email_backend.send_email_smtp"
    "email.default_email_on_retry"   = "True"
    "email.default_email_on_failure" = "True"
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "DEBUG"
    }
    scheduler_logs {
      enabled   = true
      log_level = "DEBUG"
    }
    task_logs {
      enabled   = true
      log_level = "DEBUG"
    }
    webserver_logs {
      enabled   = true
      log_level = "DEBUG"
    }
    worker_logs {
      enabled   = true
      log_level = "DEBUG"
    }
  }

  network_configuration {
    security_group_ids = [module.vpc_private_sg.security_group_id]
    subnet_ids = [
      module.vpc_private_a_subnet.subnet_id,
      module.vpc_private_b_subnet.subnet_id
    ]
  }


  depends_on = [aws_iam_role.mwaa_execution_role, aws_iam_policy.mwaa_policy, aws_iam_role_policy_attachment.mwaa_policy_attachment]

  tags = local.tags
}

# S3 bucket objects
resource "aws_s3_object" "mwaa_dags_folder" {
  for_each = toset(var.s3_objects)

  bucket  = var.aws_bucket_name
  key     = each.key
  content = ""
}

# S3 bucket object for the startup script
resource "aws_s3_object" "mwaa_startup_script" {
  bucket = var.aws_bucket_name
  key    = "scripts/mwaa_startup.sh"

  content = <<EOF
#!/bin/bash

SMTP_SECRET=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.security_manager.name} --region ${var.aws_region} | jq -r '.SecretString')

MAIL_SERVER=$(echo $SMTP_SECRET | jq -r '.MAIL_SERVER')
MAIL_PORT=$(echo $SMTP_SECRET | jq -r '.MAIL_PORT')
MAIL_USERNAME=$(echo $SMTP_SECRET | jq -r '.MAIL_USERNAME')
MAIL_PASSWORD=$(echo $SMTP_SECRET | jq -r '.MAIL_PASSWORD')
MAIL_USE_TLS=$(echo $SMTP_SECRET | jq -r '.MAIL_USE_TLS')

airflow connections add 'smtp_default' \
  --conn-type 'smtp' \
  --conn-host "$MAIL_SERVER" \
  --conn-login "$MAIL_USERNAME" \
  --conn-password "$MAIL_PASSWORD" \
  --conn-port "$MAIL_PORT" \
  --conn-extra "{\"use_tls\": $MAIL_USE_TLS, \"timeout\": 30}"
EOF
}


