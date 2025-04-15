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
  tags                 = local.tags
}

# Subnets 
module "vpc_public_a_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.0.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  subnet_name             = "${module.vpc.vpc_name}-public-a"
  route_table_id          = module.vpc.public_route_table_id
  tags                    = local.tags
}


module "vpc_public_b_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.1.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  subnet_name             = "${module.vpc.vpc_name}-public-b"
  route_table_id          = module.vpc.public_route_table_id
  tags                    = local.tags
}

module "vpc_private_a_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.2.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  subnet_name             = "${module.vpc.vpc_name}-private-a"
  route_table_id          = module.vpc.private_route_table_id
  tags                    = local.tags
}


module "vpc_private_b_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.3.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false
  subnet_name             = "${module.vpc.vpc_name}-private-b"
  route_table_id          = module.vpc.private_route_table_id
  tags                    = local.tags
}

# Security Groups
module "vpc_public_sg" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/security?ref=v1.0.0"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${module.vpc.vpc_name}-public-sg"
  description         = "Allow HTTPS inbound traffic from the internet and all protocols outbound traffic"

  ingress_rules = {
    https = {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "Allow HTTPS from anywhere"
    },

    http = {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "Allow HTTP from anywhere"
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


resource "aws_vpc_endpoint" "emr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.elasticmapreduce"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  security_group_ids  = [module.vpc_private_sg.security_group_id]
  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-emr-interface-endpoint"
    }
  )

}

# IAM 
resource "aws_iam_group" "group" {
  name = var.group_name

  lifecycle {
    prevent_destroy = true
  }

}

resource "aws_iam_user" "users" {
  for_each = toset(var.users)

  name = each.value

  lifecycle {
    prevent_destroy = true
  }


  tags = merge(local.tags, {
    Name = "${var.project_name}-iam-users"
    }
  )
}


resource "aws_iam_user_group_membership" "users_to_group" {
  for_each = toset(var.users)

  user   = aws_iam_user.users[each.value].name
  groups = [aws_iam_group.group.name]

  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_iam_user_login_profile" "users" {
  for_each = toset(var.users)

  user                    = aws_iam_user.users[each.value].name
  password_length         = var.password_length
  password_reset_required = var.password_reset_required

  lifecycle {
    ignore_changes  = [password_reset_required]
    prevent_destroy = true

  }
}


resource "aws_iam_access_key" "users" {
  for_each = var.create_access_keys ? toset(var.users) : []

  user = aws_iam_user.users[each.value].name

  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_iam_policy" "combined_policy" {
  name        = "${var.group_name}-CombinedPolicy"
  description = "policy for ${var.group_name} with read access to services"


  policy = templatefile("./policies/policy.json", {
    s3_bucket_arn  = module.s3_bucket.bucket_arn
    s3_object_arns = ["${module.s3_bucket.bucket_arn}/*"]


  })
  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_iam_group_policy_attachment" "policy_attachment" {
  group      = aws_iam_group.group.name
  policy_arn = aws_iam_policy.combined_policy.arn

  lifecycle {
    prevent_destroy = true
  }
}

# Secret Managers
resource "aws_secretsmanager_secret" "security_manager" {
  name = "${var.project_name}-security-manager3"

  tags                           = local.tags
  description                    = "Secret manager for ${var.project_name} project"
  force_overwrite_replica_secret = true

  lifecycle {
    prevent_destroy = true
  }

}

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


# Certificate Manager
# resource "aws_acm_certificate" "cert" {
#   domain_name       = "decjobboard.online"
#   validation_method = "DNS"

#   # lifecycle {
#   #   prevent_destroy = true
#   # }

#   tags = merge(local.tags, {
#     Name = "${var.project_name}-cert"
#   }
#   )
# }


# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

#   # lifecycle {
#   #   prevent_destroy = true
#   # }
# }

# Route 53
# resource "aws_route53_zone" "hosted_zone" {
#   name = "decjobboard.online"

#   tags = local.tags
# }

# resource "aws_route53_record" "alias" {
#   zone_id = aws_route53_zone.hosted_zone.id
#   name    = "decjobboard.online"
#   type    = "A"

#   alias {
#     name    = aws_lb.airflow_alb.dns_name
#     zone_id = aws_lb.airflow_alb.zone_id

#     evaluate_target_health = true
#   }

#   # lifecycle {
#   #   prevent_destroy = true
#   # }
# }

# Create DNS validation records for the certificate
# resource "aws_route53_record" "acm_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = aws_route53_zone.hosted_zone.zone_id

#   # lifecycle {
#   #   prevent_destroy = true
#   # }
# }

# Application Load Balancer
# resource "aws_lb" "airflow_alb" {
#   name               = "${var.project_name}-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [module.vpc_public_sg.security_group_id]
#   subnets            = [module.vpc_public_a_subnet.subnet_id, module.vpc_public_b_subnet.subnet_id]
#   tags = merge(local.tags, {
#     Name = "${var.project_name}-alb"
#   }
#   )
# }


# resource "aws_lb_target_group" "airflow_tg" {
#   name        = "${var.project_name}-airflow-tg"
#   port        = 443
#   protocol    = "HTTPS"
#   vpc_id      = module.vpc.vpc_id
#   target_type = "ip"

#   health_check {
#     path                = "/health"
#     protocol            = "HTTPS"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     matcher             = "200, 300"
#   }


#   stickiness {
#     type = "lb_cookie"
#   }

# }

# Register IP addresses with the target group
# resource "aws_lb_target_group_attachment" "airflow_tg_attachment" {
#   for_each = {
#     for idx, nic in data.aws_network_interface.mwaa_webserver_eni :
#     idx => nic.private_ip
#   }

#   target_group_arn = aws_lb_target_group.airflow_tg.arn
#   target_id        = each.value
#   port             = 443
# }

# resource "aws_lb_listener" "airflow_https" {
#   load_balancer_arn = aws_lb.airflow_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate.cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.airflow_tg.arn
#   }
# }

# resource "aws_lb_listener" "airflow_http_redirect" {
#   load_balancer_arn = aws_lb.airflow_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

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

resource "aws_iam_policy" "mwaa_policy" {
  name        = "${var.project_name}-mwaa-policy"
  description = "Permissions for MWAA to access S3, CloudWatch, EMR, and Secrets Manager"

  policy = templatefile("./policies/mwaa-policy.json", {
    s3_arn     = module.s3_bucket.bucket_arn
    secret_arn = aws_secretsmanager_secret.security_manager.arn

  })
}


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
  webserver_access_mode  = "PUBLIC_ONLY"


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
      log_level = "INFO"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }
    worker_logs {
      enabled   = true
      log_level = "INFO"
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

resource "aws_s3_object" "mwaa_dags_folder" {
  bucket  = var.aws_bucket_name
  key     = "dags/"
  content = ""
}

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

# resource "null_resource" "update_mwaa_domain" {
#   depends_on = [aws_mwaa_environment.big_data, aws_lb.airflow_alb, aws_route53_record.alias]

#   provisioner "local-exec" {
#     command = <<-EOT
#       aws mwaa update-environment \
#         --name ${aws_mwaa_environment.big_data.name} \
#         --airflow-configuration-options '{"webserver.base_url":"https://decjobboard.online"}' \
#         --region ${var.aws_region}
#     EOT
#   }
# }

# data "aws_vpc_endpoint" "mwaa_webserver" {
#   filter {
#     name   = "service-name"
#     values = [aws_mwaa_environment.big_data.webserver_vpc_endpoint_service]
#   }

#   depends_on = [aws_mwaa_environment.big_data]
# }

# data "aws_network_interface" "mwaa_webserver_eni" {
#   count = 2  

#   filter {
#     name   = "vpc-endpoint-id"
#     values = [data.aws_vpc_endpoint.mwaa_webserver.id]
#   }

#   filter {
#     name   = "subnet-id"
#     values = count.index == 0 ? [module.vpc_private_a_subnet.subnet_id] : [module.vpc_private_b_subnet.subnet_id]
#   }

#   depends_on = [aws_mwaa_environment.big_data]
# }

