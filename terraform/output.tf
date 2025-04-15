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

output "access_keys" {
  description = "Map of user names to access key IDs"
  value       = var.create_access_keys ? { for user in var.users : user => aws_iam_access_key.users[user].id } : {}
  sensitive   = true
}

output "secret_keys" {
  description = "Map of user names to secret access keys"
  value       = var.create_access_keys ? { for user in var.users : user => aws_iam_access_key.users[user].secret } : {}
  sensitive   = true
}

output "passwords" {
  description = "Map of user names to their initial passwords"
  value       = { for user in var.users : user => aws_iam_user_login_profile.users[user].password }
  sensitive   = true
}