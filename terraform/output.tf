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



output "user_credentials" {
  value = {
    for user in var.users : user => {
      access_key_id     = aws_iam_access_key.users[user].id
      secret_access_key = aws_iam_access_key.users[user].secret
      username          = aws_iam_user.users[user].name
    }
  }
  sensitive   = true
  description = "User credentials including access keys and secret keys"
}

output "console_login_url" {
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
  description = "AWS Console login URL"
}