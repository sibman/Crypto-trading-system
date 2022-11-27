variable iam_role {
    type = list(string)
}
variable lambda_function {
    type = list(string)
}

variable dynamodb_tb {}

variable project_tag {}

resource "aws_dynamodb_table" "demo-dynamobd-tb" {
    name           = var.dynamodb_tb
    billing_mode   = "PAY_PER_REQUEST"
    hash_key       = "Symbol"
    range_key      = "TimeFrame"
    table_class    = "STANDARD_INFREQUENT_ACCESS"

    attribute {
    name = "Symbol"
    type = "S"
    }

    attribute {
    name = "TimeFrame"
    type = "S"
    }

    tags = {
        project = var.project_tag
    }
}

# IAM role for lambda in this phrase
resource "aws_iam_role" "role" {
    name = var.iam_role[3]
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


resource "aws_iam_policy" "BacktestingAnalysisUpdatePolicy" {
    name = "BacktestingAnalysisUpdatePolicy"
    description = "Policy for BacktestingAnalysisUpdate lambda function"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:DescribeTable",
                "dynamodb:BatchGetItem",
                "dynamodb:BatchWriteItem",
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "timestream:Select",
                "timestream:PrepareQuery",
                "timestream:SelectValues",
                "timestream:DescribeDatabase",
                "timestream:DescribeEndpoints",
                "timestream:DescribeScheduledQuery",
                "timestream:DescribeTable"
            ],
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
  policy_arn = aws_iam_policy.BacktestingAnalysisUpdatePolicy.arn
}

# lambda
resource "aws_lambda_function" "lambda1" {
    function_name = "${var.lambda_function[3]}-1"
    role          = aws_iam_role.role.arn
    memory_size = 2000
    timeout = 900
    filename = "./modules/Backtest/backtest1.zip"
    runtime = "python3.9"
    package_type = "Zip"
    layers = ["arn:aws:lambda:ap-northeast-1:336392948345:layer:AWSSDKPandas-Python39:1"]
    handler  = "backtest1.handler"
    architectures = ["x86_64"]
    tags = {
        project = var.project_tag
    }
}

resource "aws_lambda_function" "lambda2" {
    function_name = "${var.lambda_function[3]}-2"
    role          = aws_iam_role.role.arn
    memory_size = 2000
    timeout = 900
    filename = "./modules/Backtest/backtest2.zip"
    runtime = "python3.9"
    package_type = "Zip"
    layers = ["arn:aws:lambda:ap-northeast-1:336392948345:layer:AWSSDKPandas-Python39:1"]
    handler  = "backtest2.handler"
    architectures = ["x86_64"]
    tags = {
        project = var.project_tag
    }
}