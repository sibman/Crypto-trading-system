project_tag = "crypto_trading_system"

iam_role = ["TopMarketCapUpdateRole","HistoricalDataUpdateRole","GlueETLRole","BacktestingAnalysisUpdateRole","TradingBotRole"]
bucket = ["bucket-phrase-1","bucket-phrase-2","bucket-phrase-3","bucket-phrase-4","bucket-phrase-5"]
lambda_function = ["TopMarketCapUpdate","HistoricalDataUpdate","","BacktestingAnalysisUpdate"]
ecr_repo = ["top-marketcap-update-image","None"]

# Glue
glue_catalog_db = "demo_catalog_db"
glue_catalog_tb = "demo_catalog_tb"
etl_job_name = "CryptoETLJob"  #This job also write results to Timestream
glue_version = "3.0"
number_of_workers = 2
external_packages = "pandas_ta, awswrangler"
# commodity_table_name = "demo-commodity-tb"

# TimestreamDB
timestream_db = "demo-ts-db"
timestream_tb = "demo-ts-tb"

#DynamoDB
dynamodb_tb = "demo-dynamodb_tb"

# commodity_table_name = "demo-commodity-tb"

# EC2 instance
vpc_cidr_block = "10.0.0.0/16"
subnet_cidr_block = "10.0.10.0/24"
avail_zone = "ap-northeast-1a"
instance_type ="t2.micro"
# ur_key1 = "/home/felix/.ssh/id_rsa.pub"
# ur_key2 = "/home/felix/.ssh/demo-terraform.pem"
# ec2_dir = "/home/ec2/demo-docker-inside-ec2.sh"

