terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.84"
        }   
    }
}

provider "aws" {
    profile = "default"
    region = "us-east-2"
}

## VPC Configuration

data "aws_availability_zones" "available_azs" {
    state = "available"
}

locals {
    azs_count = 2
    azs_names = slice(data.aws_availability_zones.available_azs.names, 0, local.azs_count)
}

resource "aws_vpc" "main_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "Mini-URL-App-VPC"
    }
}

resource "aws_subnet" "public_subnets" {
    count = local.azs_count
    vpc_id = aws_vpc.main_vpc.id
    availability_zone = local.azs_names[count.index]
    cidr_block = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, 1 + count.index)
    map_public_ip_on_launch = true
    tags = {
        Name = "Public-Subnet-${count.index + 1}"
    }
}

resource "aws_subnet" "private_subnet" {
    vpc_id = aws_vpc.main_vpc.id
    availability_zone = local.azs_names[0]
    cidr_block = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, 1 + local.azs_count)
    tags = {
        Name = "Private-Subnet-1"
    }
}

resource "aws_eip" "main_nat_eip" {
    domain = "vpc"
}

resource "aws_internet_gateway" "main_igw" {
    vpc_id = aws_vpc.main_vpc.id
    tags = {
        Name = "Mini-URL-App-IGW"
    }
}

resource "aws_nat_gateway" "main_nat" {
    subnet_id = aws_subnet.public_subnets[0].id
    allocation_id = aws_eip.main_nat_eip.id
    tags = {
        Name = "Mini-URL-App-NAT"
    }
}

resource "aws_route_table" "main_public_rt" {
    vpc_id = aws_vpc.main_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main_igw.id
    }
}

resource "aws_route_table" "main_private_rt" {
    vpc_id = aws_vpc.main_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_nat_gateway.main_nat.id
    }
}

resource "aws_route_table_association" "main_public_rt_assoc" {
    count = local.azs_count
    route_table_id = aws_route_table.main_public_rt.id
    subnet_id = aws_subnet.public_subnets[count.index].id
}

resource "aws_route_table_association" "main_private_rt_assoc" {
    route_table_id = aws_route_table.main_private_rt.id
    subnet_id = aws_subnet.private_subnet.id
}

resource "aws_security_group" "alb_sg" {
    name = "ALB-SG"
    description = "Allow HTTP traffic"
    vpc_id = aws_vpc.main_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_sgr" {
    security_group_id = aws_security_group.alb_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_egress_sgr" {
    security_group_id = aws_security_group.alb_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = -1
}

resource "aws_security_group" "ecs_node_sg" {
    name = "ECS-Node-SG"
    description = "Allow traffic from ALB"
    vpc_id = aws_vpc.main_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_node_allow_alb_sgr" {
    security_group_id = aws_security_group.ecs_node_sg.id
    referenced_security_group_id = aws_security_group.alb_sg.id
    ip_protocol = -1
}

resource "aws_vpc_security_group_egress_rule" "ecs_node_egress_sgr" {
    security_group_id = aws_security_group.ecs_node_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = -1
}

## ECS Cluster Configuration

resource "aws_ecs_cluster" "main_cluster" {
    name = "Mini-URL-App-Cluster"
}
