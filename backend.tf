terraform {
  backend "s3" {
    bucket       = "jenkins-terraform-backend-731628759499"
    key          = "eks/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

