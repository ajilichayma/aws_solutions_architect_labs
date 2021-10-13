terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region = var.region
}


/*============ The VPC =================*/
resource "aws_vpc" "vpc" {
  # cidr_block           = var.vpc_cidr 
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.environment}-vpc"
  }
}

/*============== subnets  =================*/
# --------- public subnet -------------
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.availability_zone
  # cidr_block        = cidrsubnet(var.vpc_cidr, 4, 1)
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.environment}-public_subnet"
  }
}
/* --------- private subnet -------------*/
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.availability_zone
  # cidr_block        = cidrsubnet(var.vpc_cidr, 4, 1)
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.environment}-private_subnet"
  }
}
/*============== NACL  =================*/
resource "aws_network_acl" "NACL" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.environment}-NACL"
  }
}


# egress = [
#   {
#     protocol   = "tcp"
#     rule_no    = 200
#     action     = "allow"
#     cidr_block = "10.0.1.0/24"
#     from_port  = 443
#     to_port    = 443
#   }
# ]

# ingress = [
#   {
#     protocol   = "tcp"
#     rule_no    = 100
#     action     = "allow"
#     cidr_block = "10.0.2.0/24"
#     from_port  = 80
#     to_port    = 80
#   }
# ]
resource "aws_network_acl_rule" "allow_all" {
  network_acl_id = aws_network_acl.NACL.id
  rule_number    = 100
  # egress         = false
  protocol    = -1
  rule_action = "allow"
  cidr_block  = "10.0.0.0/16"
  from_port   = 0
  to_port     = 0
}
#   resource "aws_network_acl_rule" "NACL_public_in_http" {
#   network_acl_id = aws_network_acl.NACL.id
#   rule_number    = 100
#   # egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = "10.0.1.0/24"
#   from_port      = 80
#   to_port        = 80
# }
#  resource "aws_network_acl_rule" "NACL_public_in_https" {
#   network_acl_id = aws_network_acl.NACL.id
#   rule_number    = 200
#   # egress         = false
#   protocol       = "tcp"
#   rule_action    = "allow"
#   cidr_block     = "10.0.1.0/24"
#   from_port      = 443
#   to_port        = 443
# }
/*============== IGW  =================*/
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.environment}-IGW"
  }
}
/*============== ROUTE TABLES  =================*/
/*---- create a route table for the public subnet ----*/
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.environment}-public_route_table"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.IGW.id
}

/* ---- create a route table for the private subnet ----*/
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.environment}-private_route_table"
  }
}

/* Route table associations */
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
  # gateway_id     = aws_internet_gateway.IGW.id

}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}
/*============== EC2 INSTANCES  =================*/
resource "aws_instance" "app_server1" {
  ami                    = "ami-830c94e3"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.public.id]
  key_name = "MyNewKP"

  tags = {
    Name = "${var.environment}-instance1"
  }
}
resource "aws_instance" "app_server2" {
  ami                    = "ami-830c94e3"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = {
    Name = "${var.environment}-instance2"
  }
}
/*============== key pair  =================*/


/*============== SECURITY GROUPS  =================*/
resource "aws_security_group" "public" {
  name        = "${var.environment}-publicSG"
  description = "public internet access"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-publicSG"
  }
}

resource "aws_security_group_rule" "public_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}
resource "aws_security_group_rule" "public_in_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}
resource "aws_security_group_rule" "public_in_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public_in_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}
# private security group
resource "aws_security_group" "private" {
  name        = "${var.environment}-private"
  description = "allow access only for the inbound traffic from the public subnet "
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Name = "${var.environment}-privateInstanceSG"
  }
}
resource "aws_security_group_rule" "private_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.private.id
}
resource "aws_security_group_rule" "private_in" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["10.0.1.0/24"]
  security_group_id = aws_security_group.private.id
}