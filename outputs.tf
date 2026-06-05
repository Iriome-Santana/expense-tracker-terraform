output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.api.id
}

output "public_ip" {
  description = "Elastic IP address"
  value       = aws_eip.api.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "backup_bucket_name" {
  description = "S3 backup bucket name"
  value       = aws_s3_bucket.backups.id
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.ec2_role.arn
}