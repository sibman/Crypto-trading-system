provider "aws" {
    region = "ap-northeast-1"
}

variable project_tag {}

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

# Glue
variable glue_catalog_db {}
variable glue_catalog_tb {}
variable etl_job_name {}
variable glue_version {}
variable number_of_workers {}
variable external_packages {}

# TimestreamDB
variable timestream_db {}
variable timestream_tb {}

# DynamoDB
variable dynamodb_tb {}

#EC2
variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable instance_type {}
variable avail_zone {}

module "TopMarketCapUpdate" {
    source ="./modules/TopMarketCapUpdate"
    bucket = var.bucket
    iam_role = var.iam_role
    project_tag = var.project_tag
    ecr_repo = var.ecr_repo
    lambda_function = var.lambda_function
}

module "HistoricalDataUpdate" {
    source ="./modules/HistoricalDataUpdate"
    bucket = var.bucket
    iam_role = var.iam_role
    project_tag = var.project_tag
    lambda_function = var.lambda_function
    glue_catalog_db = var.glue_catalog_db
    glue_catalog_tb = var.glue_catalog_tb
}

module "GlueETL" {
    source = "./modules/GlueETL"
    iam_role = var.iam_role
    glue_catalog_db = var.glue_catalog_db
    etl_job_name = var.etl_job_name
    glue_version = var.glue_version
    number_of_workers = var.number_of_workers
    external_packages = var.external_packages
    bucket = var.bucket
    project_tag = var.project_tag
    timestream_db = var.timestream_db
    timestream_tb = var.timestream_tb
}

module "Backtest" {
    source = "./modules/Backtest"
    dynamodb_tb = var.dynamodb_tb
    lambda_function = var.lambda_function
    iam_role = var.iam_role
    project_tag = var.project_tag
}

module "StepFunction" {
    source = "./modules/StepFunction"
    backtest1_Arn = module.Backtest.backtest1_Arn
    backtest2_Arn = module.Backtest.backtest2_Arn
    TopMarketCapUpdate_Arn = module.TopMarketCapUpdate.TopMarketCapUpdate_Arn
    HistoricalDataUpdate_Arn = module.HistoricalDataUpdate.HistoricalDataUpdate_Arn
    instance_id = module.TradingBot.instance_id
    project_tag = var.project_tag
}

module "TradingBot"{
    source = "./modules/TradingBot"
    vpc_cidr_block = var.vpc_cidr_block
    subnet_cidr_block = var.subnet_cidr_block
    instance_type = var.instance_type
    avail_zone = var.avail_zone
    bucket = var.bucket
    iam_role = var.iam_role
    project_tag = var.project_tag
}

# module "Sagemaker" {
#     source = "./modules/Sagemaker"
#     project_tag = var.project_tag
# }
