# ==============================================================================
# S3 COMPLIANCE & AUDIT LOG STORAGE
# Compliant with CIS AWS Foundations Benchmark (2.1.1 - 2.1.6)
# ==============================================================================

# Random suffix to ensure globally unique S3 bucket name
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Audit / Log Storage S3 Bucket
resource "aws_s3_bucket" "audit_bucket" {
  bucket        = "${var.project_name}-audit-logs-${random_string.suffix.result}"
  force_destroy = true # Convenient for dev/testing cleanup

  tags = {
    Name        = "${var.project_name}-audit-logs"
    Description = "CIS compliant encrypted audit & VPC flow logs storage"
  }
}

# 2. Block ALL Public Access (CIS Benchmark 2.1.1, 2.1.2, 2.1.3, 2.1.4)
resource "aws_s3_bucket_public_access_block" "audit_bucket_pab" {
  bucket = aws_s3_bucket.audit_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Enable Server-Side Encryption by Default (CIS Benchmark 2.1.5)
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_bucket_encryption" {
  bucket = aws_s3_bucket.audit_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Enable Versioning (Protects against accidental modification/deletion)
resource "aws_s3_bucket_versioning" "audit_bucket_versioning" {
  bucket = aws_s3_bucket.audit_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 5. Enforce TLS/HTTPS only via Bucket Policy (CIS Benchmark 2.1.6)
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.audit_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureHTTPTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.audit_bucket.arn,
          "${aws_s3_bucket.audit_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
