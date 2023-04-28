//iam role for ec2 to pass pictures to S3
resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225-Webapp"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Action" : "sts:AssumeRole"
        "Effect" : "Allow"
        "Sid" : ""
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    name = "EC2-CSYE6225-Webapp-${var.profile}"
  }
}

# iam policy for ec2 role to access s3 for webapp
resource "aws_iam_policy" "webapp_s3_policy" {
  name        = "WebAppS3-Policy"
  description = "Permissions for the S3 bucket to create secure policies."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:PutObjectAcl"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}/*"
          # "${aws_s3_bucket.s3_bucket.arn}",
          # "${aws_s3_bucket.s3_bucket.arn}/*"
        ]
      }
    ]
  })
}


# iam attachment for ec2 to pass pictures to S3
resource "aws_iam_role_policy_attachment" "attachRoletoEc2" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
}

# create a profile for Webapp to S3
resource "aws_iam_instance_profile" "ec2Profile" {
  name = "ec2Profile"
  role = aws_iam_role.EC2-CSYE6225.name
}
# attach CloudWatch policy to role 
resource "aws_iam_role_policy_attachment" "EC2CloudWatchAttachment" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "load_balancer_autoscaling_policy" {
  name = "load_balancer_autoscaling_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:*",
          "elasticloadbalancing:*",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "asg_policy_attachment" {
  policy_arn = aws_iam_policy.load_balancer_autoscaling_policy.arn
  role       = aws_iam_role.EC2-CSYE6225.name
}

# IAM policy for allow web application role to use kms keys
resource "aws_iam_policy" "webapp_kms_policy" {
  name        = "WebApp-KMS-Policy"
  description = "Permissions for the KMS to create secure policies."

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:RevokeGrant",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants"
        ],
        "Effect" : "Allow",
        "Resource" : [
          aws_kms_key.ebs.arn,
          aws_kms_key.rds.arn
        ]
      }
    ]
  })
}
