provider "aws" {
  profile = "default"
  region  = "us-east-1"
  default_tags {
    tags = {
      source = "tf-lab-ec2"
    }
  }
}
