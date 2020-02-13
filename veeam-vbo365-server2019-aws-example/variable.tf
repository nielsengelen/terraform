# Region to deploy
variable "region" {
	type = "string"
    default = "eu-central-1"
}

# AWS access key
variable "access_key" {
	type = "string"
	default = "XXXXX"
}

# AWS secret key
variable "secret_key" {
	type = "string"
	default = "XXXXX"
}

# AWS key pair name
variable "key_name" {
	type = "string"
	default = "terraform"
}

# AWS instance type
variable "instance_type" {
	type = "string"
	default = "t2.medium"
}

# AWS instance name
variable "instance_name" {
	type = "string"
	default = "aws_VBO365"
}

# AWS security group name
variable "security_group_name" {
	type = "string"
	default = "security_group_VBO365"
}