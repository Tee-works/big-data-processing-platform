terraform {
  backend "s3" {
    bucket       = "multi-vpc-architecture"
    key          = "state/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
    region       = "eu-north-1"

  }

}