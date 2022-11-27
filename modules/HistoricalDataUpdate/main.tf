variable bucket  {
    type = list(string)
}

variable iam_role {
    type = list(string)
}
variable lambda_function {
    type = list(string)
}

# variable ecr_repo {
#     type = list(string)
# }

variable glue_catalog_db {}
variable glue_catalog_tb {}

variable project_tag {}

# S3 bucket
resource "aws_s3_bucket" "remote-state" {
    bucket = var.bucket[1]
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
    name = var.iam_role[1]
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

resource "aws_iam_policy" "HistoricalDataUpdatePolicy" {
    name = "HistoricalDataUpdatePolicy"
    description = "An additional policy for HistoricalDataUpdate lambda function"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "glue:CreateTable",
                "glue:GetTables",
                "glue:CreateDatabase",
                "glue:CreateTrigger",
                "glue:CreateSchema",
                "glue:CreatePartition",
                "s3:ListBucket",
                "glue:GetTable",
                "glue:CreateCrawler",
                "dynamodb:BatchGetItem",
                "dynamodb:PutItem",
                "dynamodb:GetItem"
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
  policy_arn = data.aws_iam_policy.S3ObjectExecutionPolicy.arn
}

resource "aws_iam_role_policy_attachment" "attach_2" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.HistoricalDataUpdatePolicy.arn
}

# lambda
resource "aws_lambda_function" "lambda" {
    function_name = var.lambda_function[1]
    role          = aws_iam_role.role.arn
    memory_size = 1000
    timeout = 120
    filename = "./modules/HistoricalDataUpdate/HistoricalData.zip"
    runtime = "python3.9"
    package_type = "Zip"
    layers = ["arn:aws:lambda:ap-northeast-1:336392948345:layer:AWSSDKPandas-Python39:1"]
    handler  = "HistoricalData.handler"
    architectures = ["x86_64"]
    tags = {
        project = var.project_tag
    }
}

resource "aws_glue_catalog_database" "demo-database" {
    name = var.glue_catalog_db
}


# resource "aws_glue_catalog_table" "demo-table" {
#     name =  var.glue_catalog_tb
#     database_name = aws_glue_catalog_database.demo-database.id

#     parameters = {
#         compressionType = "snappy"
#         classification	= "parquet"
#         "projection.enabled" = false
#         typeOfData = "file"
#     }

#     partition_keys  {
#         name = "par"
#         type = "string"
#     }

#     storage_descriptor {
#     location      = "s3://${var.bucket[1]}"
#     input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
#     output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

#     ser_de_info {
#         serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

#         parameters = {
#             "serialization.format" = 1
#         }
#     }

#     columns {
#         name = "Time"
#         type = "bigint"
#     }
#     columns {
#         name = "Open"
#         type = "double"
#     }
#     columns {
#         name = "High"
#         type = "double"
#     }

#     columns {
#         name = "Low"
#         type = "double"
#     }

#     columns {
#         name = "Close"
#         type = "double"
#     }
#     columns {
#         name = "Volume"
#         type = "double"
#     }
#     columns {
#         name = "Quote_asset_volume"
#         type = "double"
#     }
#     columns {
#         name = "Number_of_trades"
#         type = "double"
#     }
#     columns {
#         name = "Taker_buy_base_asset_volume"
#         type = "double"
#     }
#     columns {
#         name = "Taker_buy_quote_asset_volume"
#         type = "double"
#     }
#     }
# }