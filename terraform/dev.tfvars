vpc_name             = "vpc-1"
profile              = "dev"
cidr_block           = "10.0.0.0/16"
vpc_region           = "ca-central-1"
public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets_cidr = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
availability_zones   = ["a", "b", "d"]
environment          = "dev"
key_name             = "6225_AWS_EC2"
subdomain_name       = "dev.ruolin-li.me"
subdomain_ns_ttl     = "300"


