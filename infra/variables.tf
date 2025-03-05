variable "public_key" {
  description = "Main private key for accessing to ec2 machines for our project"
  type        = string
}

variable "ec2_ami" {
  description = "Selected AMI for vm's image"
  type        = string
  default     = "ami-064519b8c76274859"
}
