output "subnet_id" {
  value = aws_subnet.main.id
}

output "security_group_id" {
  value = aws_security_group.sg_allow_egress.id
}

output "deployer_role_arn" {
  value = aws_iam_role.DeployerRole.arn
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.app_server_profile.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.main.bucket
}