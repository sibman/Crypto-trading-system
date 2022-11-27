variable project_tag {}



# resource "aws_sagemaker_domain" "example" {
#     domain_name = "example"
#     auth_mode   = "IAM"
#     vpc_id      = aws_vpc.test.id
#     subnet_ids  = [aws_subnet.test.id]

#     default_user_settings {
#     execution_role = aws_iam_role.test.arn
#     }

#     tags = {
#         project = var.project_tag
#     }
# }

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_domain#app_network_access_type
resource "aws_iam_role" "role" {
    name               = "AmazonSageMaker-ExecutionRole"
    assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "sagemaker.amazonaws.com"
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

data "aws_iam_policy" "AmazonSageMakerFullAccess" {
    name = "AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "attach_1" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.AmazonSageMakerFullAccess.arn
}


# resource  "aws_vpc" "demo-vpc" {
#     cidr_block = var.vpc_cidr_block
#     tags = {
#         project = var.project_tag
#     }
# }

# resource "aws_default_security_group" "demo-sg" {
#     vpc_id = aws_vpc.demo-vpc.id
    
#     ingress {
#         from_port = 22
#         to_port = 22
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }

#     egress {
#         from_port = 0
#         to_port = 0
#         protocol = "-1"
#         cidr_blocks = ["0.0.0.0/0"] 
#     }  

#     tags = {
#         project = var.project_tag
#     }
# }

# resource "aws_subnet" "demo-subnet" {
#     vpc_id = aws_vpc.demo-vpc.id
#     cidr_block =  var.subnet_cidr_block
#     availability_zone = var.avail_zone
#     tags = {
#         project = var.project_tag
#     }
# }

# resource "aws_internet_gateway" "demo-gate-way" {
#     vpc_id = aws_vpc.demo-vpc.id
#     tags = {
#         project = var.project_tag
#     }
# }

# resource "aws_default_route_table" "main-rtb" {
#     default_route_table_id = aws_vpc.demo-vpc.default_route_table_id
#     #Because entry destination in route talbe is VPC range, we dont have to speficy entry destination
#     #We have to create second entry for internet gateway
#     route {
#         cidr_block = "0.0.0.0/0"
#         gateway_id = aws_internet_gateway.demo-gate-way.id 
#     }
#     tags = {
#         project = var.project_tag
#     }
# }