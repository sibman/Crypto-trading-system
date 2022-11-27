variable project_tag {}
variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable instance_type {}
variable iam_role {
    type = list(string)
}
variable bucket  {
    type = list(string)
}

resource  "aws_vpc" "demo-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        project = var.project_tag
    }
}

resource "aws_default_security_group" "demo-sg" {
    vpc_id = aws_vpc.demo-vpc.id
    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"] 
    }  

    tags = {
        project = var.project_tag
    }
}

resource "aws_subnet" "demo-subnet" {
    vpc_id = aws_vpc.demo-vpc.id
    cidr_block =  var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        project = var.project_tag
    }
}

resource "aws_internet_gateway" "demo-gate-way" {
    vpc_id = aws_vpc.demo-vpc.id
    tags = {
        project = var.project_tag
    }
}

resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = aws_vpc.demo-vpc.default_route_table_id
    #Because entry destination in route talbe is VPC range, we dont have to speficy entry destination
    #We have to create second entry for internet gateway
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.demo-gate-way.id 
    }
    tags = {
        project = var.project_tag
    }
}      

resource "aws_iam_instance_profile" "ec2-profile"{
    name = "ec2-profile"
    role = "DynamodbGetRole"
}

resource "aws_instance" "EC2" {
    ami = data.aws_ami.lastest-amazon-linux-image.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.demo-subnet.id
    vpc_security_group_ids = [aws_default_security_group.demo-sg.id]
    availability_zone = var.avail_zone
    associate_public_ip_address = true
    iam_instance_profile = aws_iam_instance_profile.ec2-profile.name
    user_data = file("modules/TradingBot/bash_scripts/user-data.sh")
    key_name = "tradingbot-instance"
    tags = {
        project = var.project_tag
    }
}

data "aws_ami" "lastest-amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["amzn2-ami-kernel-5.10-hvm-2.0.20220719.0-x86_64-gp2"]
    }
}

# IAM role for EC2
resource "aws_iam_role" "role" {
    name = "DynamodbGetRole"
    assume_role_policy = <<EOF
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Action": [
                            "sts:AssumeRole"
                        ],
                        "Principal": {
                            "Service": [
                                "ec2.amazonaws.com"
                            ]
                        }
                    }
                ]
            }
        EOF
    tags = {
        project = var.project_tag
    }
}

resource "aws_iam_policy" "DynamodbGetPolicy" {
    name = "DynamodbGetPolicy"
    description = "An additional policy for DynamodbGetRole"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:ListTables",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:ListStreams",
                "dynamodb:GetRecords",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject"
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
  policy_arn = aws_iam_policy.DynamodbGetPolicy.arn
}

# s3 bucket for tradingbot script
resource "aws_s3_bucket" "remote-state" {
    bucket = var.bucket[4]
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
    bucket = var.bucket[4]
    key    = "trading_bot.zip"
    source = "./modules/TradingBot/trading_bot.zip"
    tags = {
        project = var.project_tag
    }   
}

resource "aws_s3_object" "object_2" {
    bucket = var.bucket[4]
    key    = "reboot_bash/per_boot.sh"
    source = "./modules/TradingBot/bash_scripts/per_boot.sh"
    tags = {
        project = var.project_tag
    }   
}