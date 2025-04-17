output "group_name" {
  description = "Name of the created IAM group"
  value       = aws_iam_group.group.name
}

output "group_arn" {
  description = "ARN of the created IAM group"
  value       = aws_iam_group.group.arn
}

output "user_names" {
  description = "List of created IAM user names"
  value       = [for user in aws_iam_user.users : user.name]
}

output "user_arns" {
  description = "List of created IAM user ARNs"
  value       = [for user in aws_iam_user.users : user.arn]
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}

output "public_subnet_a_id" {
  value       = module.vpn_target_subnet.subnet_id
  description = "Public Subnet A ID"
}

output "public_subnet_b_id" {
  value       = module.vpc_public_b_subnet.subnet_id
  description = "Public Subnet B ID"
}

output "private_subnet_a_id" {
  value       = module.vpc_private_a_subnet.subnet_id
  description = "Private Subnet A ID"
}

output "private_subnet_b_id" {
  value       = module.vpc_private_b_subnet.subnet_id
  description = "Private Subnet B ID"
}

output "vpc_public_sg_id" {
  value       = module.vpc_public_sg.security_group_id
  description = "The ID of the VPC public security group"

}
output "vpc_private_sg_id" {
  value       = module.vpc_private_sg.security_group_id
  description = "The ID of the VPC private security group"
}

output "user_credentials" {
  value = {
    for user in var.users : user => {
      access_key_id     = aws_iam_access_key.users[user].id
      secret_access_key = aws_iam_access_key.users[user].secret
      username          = aws_iam_user.users[user].name
      password          = aws_iam_user_login_profile.users[user].password
    }
  }
  sensitive   = true
  description = "User credentials including access keys and secret keys"
}

output "console_login_url" {
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
  description = "AWS Console login URL"
}
