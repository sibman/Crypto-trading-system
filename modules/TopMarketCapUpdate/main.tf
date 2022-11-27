variable bucket  {
    type = list(string)
}
variable iam_role {
    type = list(string)
}
variable lambda_function {
    type = list(string)
}

variable ecr_repo {
    type = list(string)
}

variable project_tag {}

# S3 bucket
resource "aws_s3_bucket" "remote-state" {
    bucket = var.bucket[0]
    tags = {
        project = var.project_tag
    }   
}

resource "aws_s3_bucket_acl" "remote-state-acl" {
    bucket = aws_s3_bucket.remote-state.id
    acl = "private" 
}

resource "aws_s3_bucket_versioning" "remote-state-versioning" {
    bucket = aws_s3_bucket.remote-state.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_public_access_block" "example" {
    bucket = aws_s3_bucket.remote-state.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# IAM role for lambda in this phrase
resource "aws_iam_role" "role" {
    name = var.iam_role[0]
    assume_role_policy = <<EOF
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }
        EOF
    tags = {
        project = var.project_tag
    }
}

data "aws_iam_policy" "S3ObjectExecutionPolicy" {
  name = "AmazonS3ObjectLambdaExecutionRolePolicy"
}

resource "aws_iam_policy" "PutObjectS3Policy" {
    name = "PutObjectS3Policy"
    description = "An additional policy for TopMarketCapUpdate lambda function"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "*"
        }
    ]
}
EOF
    tags = {
        project = var.project_tag
    }   
}


resource "aws_iam_role_policy_attachment" "attach_1" {
    role       = aws_iam_role.role.name
    policy_arn = data.aws_iam_policy.S3ObjectExecutionPolicy.arn
}

resource "aws_iam_role_policy_attachment" "attach_2" {
    role       = aws_iam_role.role.name
    policy_arn = aws_iam_policy.PutObjectS3Policy.arn
}

# lambda
data "aws_ecr_repository" "service" {
    name = var.ecr_repo[0]
    tags = {
        project = var.project_tag
    }     
}

resource "aws_lambda_function" "lambda" {
    function_name = var.lambda_function[0]
    role          = aws_iam_role.role.arn
    memory_size = 1000
    timeout = 120
    package_type = "Image"
    image_uri = "${data.aws_ecr_repository.service.repository_url}:latest"
    tags = {
        project = var.project_tag
    }
}




