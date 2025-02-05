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

data "aws_iam_policy_document" "ecs_node_doc" {
    statement {
        actions = ["sts:AssumeRole"]
        effect = "Allow"
        principals {
            type = "Service"
            identifiers = [ "ec2.amazonaws.com" ]
        }
    }
}

resource "aws_iam_role" "ecs_node_role" {
    name_prefix = "ecs-node-role-"
    assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_role_policy" {
    role = aws_iam_role.ecs_node_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_node_profile" {
    name = "ecs-node-profile"
    role = aws_iam_role.ecs_node_role.name
}

data "aws_ssm_parameter" "ecs_node_ami" {
    name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "main_asg_lt" {
    name_prefix = "mini-url-app-asg-"
    image_id = data.aws_ssm_parameter.ecs_node_ami.value
    instance_type = "t2.micro"
    iam_instance_profile {
        arn = aws_iam_instance_profile.ecs_node_profile.arn
    }
    monitoring {
        enabled = true
    }
    vpc_security_group_ids = [ aws_security_group.ecs_node_sg.id ]
    user_data = base64encode(<<-EOF
        #!/bin/bash
        echo ECS_CLUSTER=${aws_ecs_cluster.main_cluster.name} >> /etc/ecs/ecs.config
    EOF
    )
}

resource "aws_autoscaling_group" "main_asg" {
    name = "mini-url-app-asg"
    vpc_zone_identifier = [aws_subnet.private_subnet.id]
    min_size = 1
    max_size = 1
    protect_from_scale_in = false
    launch_template {
        id = aws_launch_template.main_asg_lt.id
        version = "$Latest"
    }
    tag {
        key = "AmazonECSManaged"
        value = ""
        propagate_at_launch = true
    }
}

resource "aws_ecs_capacity_provider" "main_asg_capacity_provider" {
    name = "mini-url-app-capacity-provider"
    auto_scaling_group_provider {
        auto_scaling_group_arn = aws_autoscaling_group.main_asg.arn
        managed_termination_protection = "DISABLED"
    }
}

resource "aws_ecs_cluster_capacity_providers" "main_cluster_asg_capacity_provider" {
    cluster_name = aws_ecs_cluster.main_cluster.name
    capacity_providers = [aws_ecs_capacity_provider.main_asg_capacity_provider.name]

    default_capacity_provider_strategy {
        capacity_provider = aws_ecs_capacity_provider.main_asg_capacity_provider.name
        base = 1
        weight = 100
    }
}

## ALB Configuration

resource "aws_lb" "main_alb" {
    name = "Mini-URL-App-ALB"
    load_balancer_type = "application"
    subnets = aws_subnet.public_subnets[*].id
    security_groups = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "main_alb_tg" {
    name = "Mini-URL-App-TG"
    vpc_id = aws_vpc.main_vpc.id
    port = 80
    protocol = "HTTP"
    deregistration_delay = 30
    health_check {
        enabled = true
        path = "/"
        protocol = "HTTP"
        matcher = 200
    }
}

resource "aws_lb_listener" "main_alb_listener" {
    load_balancer_arn = aws_lb.main_alb.arn
    port = 80
    protocol = "HTTP"
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.main_alb_tg.arn
    }
}

output "alb_url" {
    description = "URL of ALB"
    value = aws_lb.main_alb.dns_name
}

## ECS Service Configuration

data "aws_iam_policy_document" "ecs_task_doc" {
    statement {
        actions = ["sts:AssumeRole"]
        effect = "Allow"
        principals {
            type = "Service"
            identifiers = [ "ecs-tasks.amazonaws.com" ]
        }
    }
}

resource "aws_iam_role" "ecs_task_role" {
    name_prefix = "ecs-task-role-"
    assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role" "ecs_task_exec_role" {
    name_prefix = "ecs-task-exec-role-"
    assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_role_policy" {
    role = aws_iam_role.ecs_task_exec_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "ecs_task_logs" {
    name = "/ecs/mini-url-app-lg"
    retention_in_days = 7
}

resource "aws_ecs_task_definition" "main_task_def" {
    family = "Mini-URL-App-Task"
    task_role_arn = aws_iam_role.ecs_task_role.arn
    execution_role_arn = aws_iam_role.ecs_task_exec_role.arn
    network_mode = "bridge"
    cpu = 512
    memory = 256
    container_definitions = jsonencode([{
        name = "Mini-URL-App",
        image = var.docker_image_tag,
        essential = true,
        portMappings = [{containerPort = var.docker_container_port, hostPort = 0}],
        logConfiguration = {
            logDriver = "awslogs",
            options = {
                "awslogs-region" = "us-east-2",
                "awslogs-group" = aws_cloudwatch_log_group.ecs_task_logs.name
            }
        }
    }])
}

resource "aws_ecs_service" "main_service" {
    name = "Mini-URL-App-Service"
    cluster = aws_ecs_cluster.main_cluster.id
    task_definition = aws_ecs_task_definition.main_task_def.arn
    desired_count = 1
    depends_on = [
        aws_iam_role_policy_attachment.ecs_role_policy,
        aws_iam_role_policy_attachment.ecs_task_exec_role_policy,
        aws_lb_target_group.main_alb_tg
    ]
    load_balancer {
        target_group_arn = aws_lb_target_group.main_alb_tg.arn
        container_name = "Mini-URL-App"
        container_port = var.docker_container_port
    }
    lifecycle {
        ignore_changes = [ desired_count ]
    }
}
