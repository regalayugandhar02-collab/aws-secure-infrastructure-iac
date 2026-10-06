# ==============================================================================
# IAM SECURITY & CIS COMPLIANCE
# Compliant with CIS AWS Foundations Benchmark (Section 1)
# ==============================================================================

# 1. IAM Password Policy (CIS Benchmark 1.5 - 1.11)
resource "aws_iam_account_password_policy" "strict_policy" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
  hard_expiry                    = false
}

# 2. Least-Privilege IAM Role for Cloud Workloads (EC2 / ECS)
resource "aws_iam_role" "app_role" {
  name = "${var.project_name}-least-privilege-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-app-role"
  }
}

# 3. Attach AWS Systems Manager (SSM) Policy
# Eliminates the need to open port 22 (SSH) for instance management
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 4. Custom Scoped Policy for S3 Audit Bucket Access
resource "aws_iam_policy" "app_s3_scoped_policy" {
  name        = "${var.project_name}-s3-scoped-policy"
  description = "Allows least-privilege read/write to the application audit bucket only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ScopedS3Access"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.audit_bucket.arn,
          "${aws_s3_bucket.audit_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_s3_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_s3_scoped_policy.arn
}

# 5. Instance Profile
resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "${var.project_name}-app-instance-profile"
  role = aws_iam_role.app_role.name
}

# 6. Reusable MFA Enforcement Policy Snippet (For IAM Users/Admins)
resource "aws_iam_policy" "enforce_mfa_policy" {
  name        = "${var.project_name}-enforce-mfa-policy"
  description = "Denies all AWS API actions if user has not authenticated with MFA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}
