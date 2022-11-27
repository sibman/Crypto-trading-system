variable project_tag {}
variable glue_catalog_db {}
variable etl_job_name {}
variable glue_version {}
variable number_of_workers {}
variable external_packages {}
variable iam_role {
    type = list(string)
}
variable bucket  {
    type = list(string)
}
variable timestream_db {}
variable timestream_tb {}


# IAM role for glue job
resource "aws_iam_role" "GlueETLRole" {
    name = var.iam_role[2]
    assume_role_policy = <<EOF
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "glue.amazonaws.com"
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

data "aws_iam_policy" "AWSGlueServiceRole" {
  name = "AWSGlueServiceRole"
}

data "aws_iam_policy" "AmazonAthenaFullAccess" {
  name = "AmazonAthenaFullAccess"
}


resource "aws_iam_policy" "AllowWriteTimeStream" {
    name = "AllowWriteTimeStreamPolicy"
    description = "An additional policy for AllowWriteTimeStream lambda function"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "timestream:DescribeDatabase",
                "timestream:DescribeEndpoints",
                "timestream:WriteRecords",
                "timestream:CreateDatabase",
                "timestream:DescribeTable",
                "timestream:CreateTable",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:AbortMultipartUpload",
                "s3:PutObject",
                "s3:ListMultipartUploadParts"
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
  role       = aws_iam_role.GlueETLRole.name
  policy_arn = data.aws_iam_policy.AWSGlueServiceRole.arn
}

resource "aws_iam_role_policy_attachment" "attach_2" {
  role       = aws_iam_role.GlueETLRole.name
  policy_arn = aws_iam_policy.AllowWriteTimeStream.arn
}

resource "aws_iam_role_policy_attachment" "attach_3" {
  role       = aws_iam_role.GlueETLRole.name
  policy_arn = data.aws_iam_policy.AmazonAthenaFullAccess.arn
}

# Timestream table
resource "aws_timestreamwrite_database" "demo-ts-db" {
    database_name = var.timestream_db
    tags = {
        project = var.project_tag
    }
}  

resource "aws_timestreamwrite_table" "demo-ts-tb" {
    database_name = aws_timestreamwrite_database.demo-ts-db.database_name
    table_name    = var.timestream_tb

    retention_properties {
        magnetic_store_retention_period_in_days = 3650
        memory_store_retention_period_in_hours  = 12
    }

    tags = {
        project = var.project_tag
    }
}

# resource "aws_timestreamwrite_table" "demo-commodity-tb" {
#     database_name = aws_timestreamwrite_database.demo-ts-db.database_name
#     table_name    = var.commodity_table_name

#     retention_properties {
#         magnetic_store_retention_period_in_days = 30
#         memory_store_retention_period_in_hours  = 8
#     }

#     magnetic_store_write_properties {
#         enable_magnetic_store_writes = true
#     }

#     tags = {
#         project = var.project_tag
#     }
# }

# Glue job
resource "aws_glue_job" "aws_glue_job"  {
    name = var.etl_job_name
    role_arn = aws_iam_role.GlueETLRole.arn
    glue_version = var.glue_version
    max_retries = 1
    execution_class = "FLEX"
    number_of_workers = var.number_of_workers
    worker_type = "G.1X"

    command {
        script_location = "s3://${var.bucket[2]}/glue_job.py"
    }   
    default_arguments = {
        "--job-language" = "python"
        "--additional-python-modules" = var.external_packages
    } 
    tags = {
        project = var.project_tag
    } 
}

# s3 bucket for glue job script
resource "aws_s3_bucket" "remote-state" {
    bucket = var.bucket[2]
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

resource "aws_s3_object" "object" {
    bucket = var.bucket[2]
    key    = "glue_job.py"
    source = "./modules/GlueETL/glue_job.py"
    tags = {
        project = var.project_tag
    }   
}
