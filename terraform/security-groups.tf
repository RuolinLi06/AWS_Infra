# Application security group 
# Update security group: Only allows ingress from load balancerOnly allows ingress from load balancer 
resource "aws_security_group" "application" {
  name        = "application"
  description = "EC2 security group for EC2 instances that host web applications"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "for MySQL/MariaDB"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # security_groups = [aws_security_group.database_security_group.id]
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description     = "Listener for Load Balancer"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.loadBalancer.id]
  }
  ingress {
    description     = "For HTTPS from Load Balancer"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.loadBalancer.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "application"
  }
}

# Database security group
resource "aws_security_group" "database_security_group" {
  name        = "DBSecurityGroup"
  description = "EC2 security group for your RDS instances."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "for MySQL/MariaDB"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  tags = {
    Name = "database"
  }

}

# Load balancer security group, enable HTTPS port to secure connections to load balancer 
resource "aws_security_group" "loadBalancer" {
  name        = "loadBalancer"
  description = "EC2 security group for load balancer."
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "For HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "For Health Checks from Application Security Group"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
