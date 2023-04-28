# aws-infra
## setting up AWS infrastructure using Terraform

Terraform AWS Provider version = 4.54.0
```
    source  = "hashicorp/aws"
    version = ">= 4.0"
```

Plan & Apply with different .tfvars
```
  terraform apply -var-file="dev.tfvars"
  
  terraform apply -var-file="prod.tfvars"
```

- Create Virtual Private Cloud (VPC).
- Create 3 public subnets and 3 private subnets, each in a different availability zone in the same region in the same VPC.
- Create an Internet Gateway resource and attach the Internet Gateway to the VPC.
- Create a public route table. Attach all public subnets created to the route table.
- Create a private route table. Attach all private subnets created to the route table.
- Create a public route in the public route table created above with the destination CIDR block 0.0.0.0/0 and the internet gateway created above as the target.

- Build the EC2 instance from Amazon Linux2 AMI
- Deploy the application on the EC2 instance (Assignment 4)

- Create a private S3 bucket with a randomly generated bucket name depending on the environment.Terraform can delete the bucket even if it is not empty. Enable default encryption for S3 Buckets. Create a lifecycle policy for the bucket to transition objects from STANDARD storage class to STANDARD_IA storage class after 30 days. 
- Create DB Security Group for RDS instances.
- Create RDS new parameter group to match database (Postgres or MySQL) and its version. 
- Create RDS instance on Private subnet with no Public accessibility.
- Use User Data to transfer variables to application when launching EC2 instance.
- Add AMI role for the EC2 service and attach the S3 bucket policy to it. 
- Give Application permissions to operate S3 Bucket using AWS instance profile credentials. Get the policy from profile instance launching the EC2.

- Add/Update A record to the Route53 zone so that your domain points to EC2 instance and your web application is accessible by http://your-domain-name.tld/. Application is accessible using root context.

```
http://dev.ruolin-li.me:8080/healthz
http://demo.ruolin-li.me:8080/healthz
```
