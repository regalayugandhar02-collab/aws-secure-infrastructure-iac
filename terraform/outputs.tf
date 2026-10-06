output "vpc_id" {
  description = "ID of the custom secure VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of Public Subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of Private App Subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of Isolated Private DB Subnet IDs"
  value       = aws_subnet.private_db[*].id
}

output "audit_s3_bucket_name" {
  description = "Name of the CIS-compliant encrypted audit S3 bucket"
  value       = aws_s3_bucket.audit_bucket.id
}

output "web_security_group_id" {
  description = "Security Group ID for Web / DMZ tier"
  value       = aws_security_group.web_sg.id
}

output "app_security_group_id" {
  description = "Security Group ID for Application tier"
  value       = aws_security_group.app_sg.id
}

output "db_security_group_id" {
  description = "Security Group ID for Database tier"
  value       = aws_security_group.db_sg.id
}

output "app_instance_profile_name" {
  description = "IAM Instance Profile for secure SSM access without open SSH"
  value       = aws_iam_instance_profile.app_instance_profile.name
}
