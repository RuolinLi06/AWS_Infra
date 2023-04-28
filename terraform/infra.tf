# Generate a random vm name
resource "random_string" "vm-name" {
  length  = 10
  upper   = false
  numeric = false
  lower   = true
  special = false
}

# Machine Name
locals {
  vm-name = "${random_string.vm-name.result}-${var.environment}"
}

#S3 bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket        = local.vm-name
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    id      = "StorageTransitionRule"
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "rds-subnet-group"
  subnet_ids  = aws_subnet.private_subnet.*.id
  description = "subnetgroup for database"
}

# Custom parameter group
resource "aws_db_parameter_group" "mydb_param_group" {
  name        = "mydb-param-group"
  family      = "mariadb10.5"
  description = "Custom parameter group for MariaDB 10.5"
}

# Customer managed key for rds
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
}

# Rds
resource "aws_db_instance" "csye6225_rds" {
  allocated_storage      = 5
  identifier             = "csye6225"
  engine                 = "mariadb"
  engine_version         = "10.5"
  instance_class         = "db.t3.micro"
  multi_az               = false
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.mydb_param_group.name
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_security_group.id]
  skip_final_snapshot    = true
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds.arn
  tags = {
    "Name" = "rds-csye6225"
  }
}

#Route 53 DNS
#reference the existing zone by its ID or by its name.
#update public subdomain zone 
data "aws_route53_zone" "sub_zone" {
  name = var.subdomain_name
}

#update/add a record for public subdomain
resource "aws_route53_record" "a_record" {
  zone_id = data.aws_route53_zone.sub_zone.zone_id
  name    = var.subdomain_name
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}


data "template_file" "user_data" {

  template = <<-EOF
    #!/bin/bash

    echo "[Unit]
    Description=webapp
    Restart=always
    [Service]
    Type=simple
    ExecStart=/opt/jdk-17/bin/java -jar /home/ec2-user/webapp-0.0.1-SNAPSHOT.jar
    Environment=DB_ENDPOINT=${aws_db_instance.csye6225_rds.endpoint}
    Environment=DB_USERNAME=${var.db_username}
    Environment=DB_PASSWORD=${var.db_password}
    Environment=S3_BUCKET=${aws_s3_bucket.s3_bucket.bucket}
    [Install]
    WantedBy=multi-user.target" >> /etc/systemd/system/test.service

    sudo chmod -R /home/ec2-user/
    sudo chmod -R /opt/aws/amazon-cloudwatch-agent/bin/
    # update aws cloudwatch agent config 
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/cloudwatch_config.json -s
    sudo systemctl start amazon-cloudwatch-agent.service
    sudo systemctl enable amazon-cloudwatch-agent.service
    sudo systemctl status -l amazon-cloudwatch-agent.service

    # Reload the systemd configuration and start the service
    sudo systemctl daemon-reload
    sudo chmod +x /etc/systemd/system/test.service
    sudo systemctl enable test.service
    sudo systemctl start test.service

 EOF

}

resource "aws_launch_template" "lt" {
  name          = "launch-template-6225"
  image_id      = var.ami
  instance_type = "t2.micro"
  key_name      = var.key_name

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 8
      encrypted   = true
      kms_key_id  = aws_kms_key.ebs.arn
      volume_type = "gp2"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.application.id]
  }
  user_data = base64encode(data.template_file.user_data.rendered)
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2Profile.name
  }
  # vpc_security_group_ids = [aws_security_group.application.id]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "csye6225"
    }
  }
}


#Autoscaling Group Scale Up policy and alarm
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale_up_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

#Autoscaling Group Scale Down policy and alarm
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "scale_down_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

#Metric monitors CPU utilization
resource "aws_cloudwatch_metric_alarm" "CPU-high" {
  alarm_name          = "cpu_alarm_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors EC2 instance CPU high utilization on agent hosts. Scale up if CPU is > 5% for 2 minute"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up_policy.arn]

}

resource "aws_cloudwatch_metric_alarm" "CPU-low" {
  alarm_name          = "cpu_alarm_low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "3"
  alarm_description   = "This metric monitors  EC2 instance CPU low utilization on agent hosts. Scale down if CPU is < 3% for 2 minute"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down_policy.arn]
}

# Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  name                      = "csye6225-asg-spring2023"
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  health_check_grace_period = 300
  # launch_configuration      = aws_launch_configuration.aws_launch_config.name
  default_cooldown    = 60
  health_check_type   = "ELB"
  vpc_zone_identifier = [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id]
  #availability_zones        = ["ca-central-1a", "ca-central-1b"]
  tag {
    key                 = "Name"
    value               = "csye6225-asg"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.alb_tg.arn]

}

#Load balancer target group 
resource "aws_lb_target_group" "alb_tg" {
  name        = "lb-target-group"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"

  deregistration_delay = 30
  health_check {
    enabled             = true
    path                = "/healthz"
    port                = 8080
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

# Load Balancer 
resource "aws_lb" "lb" {
  name               = "csye6225-lb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.loadBalancer.id]
  subnets            = aws_subnet.public_subnet.*.id
  tags = {
    Application = "WebApp"
  }
}

# ACM certificate
data "aws_acm_certificate" "ssl_certificate" {
  domain   = var.subdomain_name
  statuses = ["ISSUED"]
}

# Load Balancer Listener Foward to Targets Group 
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.ssl_certificate.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}
# current user profile
data "aws_caller_identity" "current" {}

# Customer Managed Key for EBS
# Policy for autoscaling service role to of this ebs key
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume"
  deletion_window_in_days = 10
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Id" : "key-default-1",
      "Statement" : [
        {
          "Sid" : "Enable IAM User Permissions",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          },
          "Action" : [
            "kms:Create*",
            "kms:Describe*",
            "kms:Enable*",
            "kms:List*",
            "kms:Put*",
            "kms:Update*",
            "kms:Revoke*",
            "kms:Disable*",
            "kms:Get*",
            "kms:Delete*",
            "kms:ScheduleKeyDeletion",
            "kms:CancelKeyDeletion"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "Allow service-linked role use of the CMK",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            ]
          },
          "Action" : [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "Allow attachment of persistent resources",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            ]
          },
          "Action" : [
            "kms:CreateGrant"
          ],
          "Resource" : "*",
          "Condition" : {
            "Bool" : {
              "kms:GrantIsForAWSResource" : true
            }
          }
        }
      ]
    }
  )
}

resource "aws_ebs_default_kms_key" "ebs" {
  key_arn = aws_kms_key.ebs.arn
}

# resource "aws_instance" "EC2_instance" {
#   ami                    = var.ami
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.application.id]
#   subnet_id              = element(aws_subnet.public_subnet.*.id, 0) # Selects the first subnet from the list of subnets defined by count 
#   key_name               = var.key_name
#   iam_instance_profile   = aws_iam_instance_profile.ec2Profile.name

#   user_data = <<-EOF
#     #!/bin/bash

#     echo "[Unit]
#     Description=webapp
#     Restart=always
#     [Service]
#     Type=simple
#     ExecStart=/opt/jdk-17/bin/java -jar /home/ec2-user/webapp-0.0.1-SNAPSHOT.jar
#     Environment=DB_ENDPOINT=${aws_db_instance.csye6225_rds.endpoint}
#     Environment=DB_USERNAME=${var.db_username}
#     Environment=DB_PASSWORD=${var.db_password}
#     Environment=S3_BUCKET=${aws_s3_bucket.s3_bucket.bucket}
#     [Install]
#     WantedBy=multi-user.target" >> /etc/systemd/system/test.service

#     sudo chmod -R /home/ec2-user/
#     sudo chmod -R /opt/aws/amazon-cloudwatch-agent/bin/

#     # update aws cloudwatch agent config 
#     sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/cloudwatch_config.json -s

#     sudo systemctl start amazon-cloudwatch-agent.service
#     sudo systemctl enable amazon-cloudwatch-agent.service
#     sudo systemctl status -l amazon-cloudwatch-agent.service

#     # Reload the systemd configuration and start the service
#     sudo systemctl daemon-reload
#     sudo chmod +x /etc/systemd/system/test.service
#     sudo systemctl enable test.service
#     sudo systemctl start test.service

#     EOF

#   tags = {
#     Name = "EC2 instance"
#   }

# }
