# Define common tags for all resources
locals {
  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Get current AWS account ID for use in IAM policies and resource naming
data "aws_caller_identity" "current" {}

# Create VPC with CIDR block 10.100.0.0/16
# This is the main networking component that will host all other resources
module "vpc" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/vpc?ref=v1.0.1"

  cidr_block           = var.cidr_block
  vpc_name             = var.vpc_name
  create_igw           = true # Create Internet Gateway for public internet access
  enable_dns_support   = true # Enable DNS resolution within VPC
  enable_dns_hostnames = true # Enable DNS hostnames for EC2 instances
  tags = merge(local.tags, {
    Name = "${var.project_name}-vpc"
    }
  )
}

# Create public subnet in AZ-a for VPN target
# This subnet will host the VPN endpoint and NAT Gateway
module "vpn_target_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.0.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # Enable automatic public IP assignment
  subnet_name             = "${module.vpc.vpc_name}-public-a"
  route_table_id          = module.vpc.public_route_table_id
  tags = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-public-a"
    }
  )
}

# Create second public subnet in AZ-b for high availability
# This subnet will host the second NAT Gateway
module "vpc_public_b_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.1.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  subnet_name             = "${module.vpc.vpc_name}-public-b"
  route_table_id          = module.vpc.public_route_table_id
  tags = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-public-b"
    }
  )
}

# Create first private subnet in AZ-a
# This subnet will host EMR and MWAA resources
module "vpc_private_a_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.3.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false # No public IP assignment for private subnet
  subnet_name             = "${module.vpc.vpc_name}-private-a"
  route_table_id          = aws_route_table.private_a.id
  tags = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-private-a"
    }
  )
}

# Create second private subnet in AZ-b for high availability
# This subnet will host backup EMR and MWAA resources
module "vpc_private_b_subnet" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/subnets?ref=v1.0.0"

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = "10.100.4.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false
  subnet_name             = "${module.vpc.vpc_name}-private-b"
  route_table_id          = aws_route_table.private_b.id
  tags = merge(local.tags, {
    Name = "${module.vpc.vpc_name}-private-b"
    }
  )
}

# Create route table for private subnet A
# This route table will be associated with private subnet A and route traffic through NAT Gateway A
resource "aws_route_table" "private_a" {
  vpc_id = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${var.project_name}-private-a-rt"
  })
}

# Create route table for private subnet B
# This route table will be associated with private subnet B and route traffic through NAT Gateway B
resource "aws_route_table" "private_b" {
  vpc_id = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${var.project_name}-private-b-rt"
  })
}

# Import server certificate for VPN endpoint
# This certificate is used to authenticate the VPN server
resource "aws_acm_certificate" "server_certificate" {
  private_key       = file("certificates/vpn.example.com.key")
  certificate_body  = file("certificates/vpn.example.com.crt")
  certificate_chain = file("certificates/ca.crt")

  tags = merge(local.tags, {
    Name = "${var.project_name}-server-cert"
    }
  )
}

# Import client certificate for VPN authentication
# This certificate is used to authenticate VPN clients
resource "aws_acm_certificate" "client_certificate" {
  private_key       = file("certificates/client1.domain.tld.key")
  certificate_body  = file("certificates/client1.domain.tld.crt")
  certificate_chain = file("certificates/ca.crt")

  tags = merge(local.tags, {
    Name = "${var.project_name}-client-cert"
    }
  )
}

# Create AWS Client VPN endpoint
# This provides secure remote access to the VPC resources
resource "aws_ec2_client_vpn_endpoint" "client_vpn" {
  description            = "BuildItAll client VPN"
  server_certificate_arn = aws_acm_certificate.server_certificate.arn
  client_cidr_block      = "10.0.0.0/16" # IP range for VPN clients
  split_tunnel           = true          # Only route VPC traffic through VPN
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

# Associate VPN endpoint with the target subnet
# This allows VPN clients to access resources in the VPC
resource "aws_ec2_client_vpn_network_association" "aws_ec2_client_vpn_network_association" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn.id
  subnet_id              = module.vpn_target_subnet.subnet_id
}

# Create authorization rule for VPN access
# This allows VPN clients to access the VPC CIDR range
resource "aws_ec2_client_vpn_authorization_rule" "client_vpn_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn.id
  target_network_cidr    = var.cidr_block
  authorize_all_groups   = true
  description            = "Allow access to all groups"
}

# Create security group for VPN target subnet
# This controls inbound and outbound traffic for the VPN endpoint
module "vpn_target_subnet_sg" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/security?ref=v1.0.0"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${module.vpc.vpc_name}-vpn-target-subnet-sg"
  description         = "Allow all protocols outbound traffic and HTTPS inbound traffic only from cidr range"

  ingress_rules = {
    https = {
      cidr_ipv4   = "10.0.0.0/16" # Allow HTTPS from VPN clients
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "Allow HTTPS from VPN client"
    }
  }
  egress_rules = {
    all = {
      cidr_ipv4   = "0.0.0.0/0" # Allow all outbound traffic
      ip_protocol = "-1"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpn-target-subnet-sg"
    }
  )
}

# Create Elastic IP for NAT Gateway A
# This provides a static public IP for NAT Gateway A
resource "aws_eip" "nat_eip_a" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-eip-a"
    }
  )
}

# Create Elastic IP for NAT Gateway B
# This provides a static public IP for NAT Gateway B
resource "aws_eip" "nat_eip_b" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-eip-b"
    }
  )
}

# Create NAT Gateway A in public subnet A
# This allows private subnet resources to access the internet
resource "aws_nat_gateway" "private_nat_gateway_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = module.vpn_target_subnet.subnet_id

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-gateway-a"
    }
  )
}

# Create NAT Gateway B in public subnet B
# This provides high availability for internet access
resource "aws_nat_gateway" "private_nat_gateway_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = module.vpc_public_b_subnet.subnet_id

  tags = merge(local.tags, {
    Name = "${var.project_name}-nat-gateway-b"
    }
  )
}

# Create route for private subnet A to NAT Gateway A
# This routes all outbound traffic from private subnet A through NAT Gateway A
resource "aws_route" "private_a_to_nat" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0" # Route all outbound traffic
  nat_gateway_id         = aws_nat_gateway.private_nat_gateway_a.id
}

# Create route for private subnet B to NAT Gateway B
# This routes all outbound traffic from private subnet B through NAT Gateway B
resource "aws_route" "private_b_to_nat" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0" # Route all outbound traffic
  nat_gateway_id         = aws_nat_gateway.private_nat_gateway_b.id
}

# Associate private subnet A with its route table
# This ensures traffic from private subnet A uses the correct routing
resource "aws_route_table_association" "private_a_assoc" {
  subnet_id      = module.vpc_private_a_subnet.subnet_id
  route_table_id = aws_route_table.private_a.id
}

# Associate private subnet B with its route table
# This ensures traffic from private subnet B uses the correct routing
resource "aws_route_table_association" "private_b_assoc" {
  subnet_id      = module.vpc_private_b_subnet.subnet_id
  route_table_id = aws_route_table.private_b.id
}

# Create security group for public subnets
# This controls inbound and outbound traffic for public resources
module "vpc_public_sg" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/security?ref=v1.0.0"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${module.vpc.vpc_name}-public-sg"
  description         = "Allow all protocols outbound traffic and HTTPS inbound traffic only from cidr range"

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
      cidr_ipv4   = "0.0.0.0/0" # Allow all outbound traffic
      ip_protocol = "-1"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-public-sg"
    }
  )
}

# Create security group for private subnets
# This controls inbound and outbound traffic for private resources
module "vpc_private_sg" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/security?ref=v1.0.0"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${module.vpc.vpc_name}-private-sg"
  description         = "Allow all protocols outbound traffic and HTTPS inbound traffic only from cidr range"

  ingress_rules = {
    vpc_a = {
      cidr_ipv4   = var.cidr_block
      ip_protocol = "-1"
      description = "Allow all protocol from VPC"
    }
  }

  egress_rules = {
    all = {
      cidr_ipv4   = "0.0.0.0/0" # Allow all outbound traffic
      ip_protocol = "-1"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-private-sg"
    }
  )
}


# Create S3 Gateway Endpoint
# This enables private connectivity to S3 without internet access
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.private_a.id,
    aws_route_table.private_b.id,
  ]
  tags = merge(local.tags, {
    Name = "${var.project_name}-s3-endpoint"
    }
  )
}

# # Create CloudWatch Logs Interface Endpoint
# # This enables private subnet resources to send logs to CloudWatch
resource "aws_vpc_endpoint" "logs" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  security_group_ids = [module.vpc_private_sg.security_group_id]

  tags = merge(local.tags, {
    Name = "${var.project_name}-logs-endpoint"
    }
  )
}

# # Create Secrets Manager Interface Endpoint
# # This enables secure access to secrets without internet exposure
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  security_group_ids = [module.vpc_private_sg.security_group_id]

  tags = merge(local.tags, {
    Name = "${var.project_name}-secretsmanager-endpoint"
    }
  )
}

# # Create SQS Interface Endpoint
# This enables private communication between services
resource "aws_vpc_endpoint" "sqs" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  security_group_ids = [module.vpc_private_sg.security_group_id]

  tags = merge(local.tags, {
    Name = "${var.project_name}-sqs-endpoint"
    }
  )
}

# # Create EMR Interface Endpoint
# # This enables secure communication with EMR control plane
resource "aws_vpc_endpoint" "emr" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.elasticmapreduce"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  security_group_ids = [module.vpc_private_sg.security_group_id]

  tags = merge(local.tags, {
    Name = "${var.project_name}-emr-endpoint"
    }
  )
}

# # Create IAM group for users
# # This group will be used to manage user permissions
resource "aws_iam_group" "group" {
  name = var.group_name
}

# # Create IAM users and attach them to the group
# # These users will have access to the platform
resource "aws_iam_user" "users" {
  for_each = toset(var.users)

  name = each.value

  tags = merge(local.tags, {
    Name = "${var.project_name}-${each.value}"
    }
  )
}

# # Add users to the IAM group
# # This ensures consistent permissions across users
resource "aws_iam_user_group_membership" "users_to_group" {
  for_each = toset(var.users)

  user   = aws_iam_user.users[each.value].name
  groups = [aws_iam_group.group.name]
}

# # Create login profiles for users
# # This enables console access with secure password policies
resource "aws_iam_user_login_profile" "users" {
  for_each = toset(var.users)

  user                    = aws_iam_user.users[each.value].name
  password_length         = var.password_length
  password_reset_required = var.password_reset_required
}

# Create access keys for users
# This enables programmatic access to AWS services
resource "aws_iam_access_key" "users" {
  for_each = toset(var.users)

  user = aws_iam_user.users[each.value].name
}

# # Create combined IAM policy
# # This policy grants necessary permissions for the platform
resource "aws_iam_policy" "combined_policy" {
  name        = "${var.group_name}-CombinedPolicy"
  description = "policy for ${var.group_name} with read access to services"

  policy = templatefile("./policies/policy.json", {
    s3_bucket_arn            = module.s3_bucket.bucket_arn
    s3_object_arns           = ["${module.s3_bucket.bucket_arn}/*"]
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.logs.arn
    mwaa_arn                 = aws_mwaa_environment.big_data.arn
    mwa_region               = var.aws_region


  })
}

# # Attach policy to IAM group
# # This applies the permissions to all group members
resource "aws_iam_group_policy_attachment" "policy_attachment" {
  group      = aws_iam_group.group.name
  policy_arn = aws_iam_policy.combined_policy.arn
}

# Secret Managers
resource "aws_secretsmanager_secret" "security_manager" {
  name = "${var.project_name}-security-manager10"

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
  name              = "/aws/vpn/${var.project_name}"
  retention_in_days = 30

  tags = merge(local.tags, {
    Name = "${var.project_name}-vpn-logs"
    }
  )
}

# # Create CloudWatch log stream for VPN
# # This organizes VPN logs within the log group
resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "vpn-connections"
  log_group_name = aws_cloudwatch_log_group.logs.name
}

# # Create S3 bucket for MWAA DAGs
# # This stores Airflow DAG definitions and configurations
module "s3_bucket" {
  source = "git::https://github.com/Chideraozigbo/My-Terraform-Modules.git//modules/s3?ref=v1.0.3"

  bucket_name = var.aws_bucket_name

  enable_versioning = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-s3-bucket"
    }
  )
}

# # Create IAM role for MWAA execution
# # This role allows MWAA to access necessary AWS services
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
    Name = "${var.project_name}-mwaa-execution-role"
    }
  )
}

# # Create IAM role for EMR service
# # This role allows EMR to access necessary AWS services
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

  tags = merge(local.tags, {
    Name = "${var.project_name}-emr-service-role"
    }
  )
}

# # Attach EMR service role policy
# # This grants EMR necessary permissions
resource "aws_iam_role_policy_attachment" "emr_service_role_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

# Create additional EMR service policy
# This grants additional permissions needed for the platform
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
}

# # Attach additional EMR service policy
# # This applies the additional permissions to the EMR service role
resource "aws_iam_role_policy_attachment" "emr_service_additional_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = aws_iam_policy.emr_service_additional_policy.arn
}

# Create IAM role for EMR EC2 instances
# This role allows EMR EC2 instances to access necessary AWS services
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

  tags = merge(local.tags, {
    Name = "${var.project_name}-emr-ec2-role"
    }
  )
}

# # Attach EMR EC2 role policy
# # This grants EMR EC2 instances necessary permissions
resource "aws_iam_role_policy_attachment" "emr_ec2_role_attachment" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Create IAM instance profile for EMR EC2
# This allows EMR to launch EC2 instances with the correct permissions
resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
  name = "EMR_EC2_DefaultRole"
  role = aws_iam_role.emr_ec2_role.name
}

# Create MWAA policy
# This grants MWAA necessary permissions for operation
resource "aws_iam_policy" "mwaa_policy" {
  name        = "${var.project_name}-mwaa-policy"
  description = "Policy for MWAA to access necessary services"

  policy = templatefile("./policies/mwaa-policy.json", {
    s3_arn = module.s3_bucket.bucket_arn
    #secret_arn   = aws_secretsmanager_secret.security_manager.arn
    emr_role_arn = aws_iam_role.emr_service_role.arn,
    emr_ec2_arn  = aws_iam_role.emr_ec2_role.arn
    project_name = "${var.project_name}-mwaa"
    mwa_region   = var.aws_region
    account_id   = data.aws_caller_identity.current.account_id

  })
}

# Attach MWAA policy to execution role
# This applies the permissions to the MWAA execution role
resource "aws_iam_role_policy_attachment" "mwaa_policy_attachment" {
  role       = aws_iam_role.mwaa_execution_role.name
  policy_arn = aws_iam_policy.mwaa_policy.arn
}

# Create security group for MWAA
# This controls network access to the MWAA environment
resource "aws_security_group" "mwaa" {
  name        = "mwaa-self-referencing"
  description = "MWAA security group"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${var.project_name}-mwaa-sg"
    }
  )
}

# # Add ingress rule for MWAA security group
# # This allows MWAA components to communicate with each other
resource "aws_vpc_security_group_ingress_rule" "self_ingress" {
  security_group_id = aws_security_group.mwaa.id

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.mwaa.id
  description                  = "Allow all traffic from the same security group"
}

# # Add ingress rule for VPC traffic
# # This allows communication from within the VPC
resource "aws_vpc_security_group_ingress_rule" "vpc_ingress" {
  security_group_id = aws_security_group.mwaa.id
  cidr_ipv4         = var.cidr_block
  ip_protocol       = "-1"
  description       = "Allow all traffic from VPC"
}

# # Add egress rule for MWAA security group
# # This allows MWAA to access the internet and other services
resource "aws_vpc_security_group_egress_rule" "mwaa_egress" {
  security_group_id = aws_security_group.mwaa.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all traffic to the internet"
}

# Create MWAA environment
# This sets up the managed Apache Airflow environment
resource "aws_mwaa_environment" "big_data" {
  name                   = "${var.project_name}-mwaa"
  execution_role_arn     = aws_iam_role.mwaa_execution_role.arn
  dag_s3_path            = "dags/"
  source_bucket_arn      = module.s3_bucket.bucket_arn
  environment_class      = "mw1.micro"
  startup_script_s3_path = "scripts/mwaa_startup.sh"
  webserver_access_mode  = "PRIVATE_ONLY"

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = [module.vpc_private_a_subnet.subnet_id, module.vpc_private_b_subnet.subnet_id]
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
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

  depends_on = [aws_iam_role.mwaa_execution_role, aws_iam_policy.mwaa_policy, aws_iam_role_policy_attachment.mwaa_policy_attachment]

  tags = local.tags
}

# Create DAGs folder in S3
# This initializes the directory structure for Airflow DAGs
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

# Extract values from the secret
MAIL_USERNAME=$(echo $SMTP_SECRET | jq -r '.MAIL_USERNAME')
MAIL_PASSWORD=$(echo $SMTP_SECRET | jq -r '.MAIL_PASSWORD')
MAIL_SERVER=$(echo $SMTP_SECRET | jq -r '.MAIL_SERVER')
MAIL_PORT=$(echo $SMTP_SECRET | jq -r '.MAIL_PORT')

# Add environment variables in Airflow as Variables
airflow variables set 'email_sender' "$MAIL_USERNAME"
airflow variables set 'email_password' "$MAIL_PASSWORD"
airflow variables set 'MAIL_SERVER' "$MAIL_SERVER"
airflow variables set 'email_port' "$MAIL_PORT"
EOF
}



