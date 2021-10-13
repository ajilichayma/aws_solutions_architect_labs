variable "region" {
  type        = string
  description = "AWS Deployment region.."
}
variable "vpc_cidr" {
  description = "value"
}
variable "availability_zone" {
  type        = string
  description = "AWS Availability zone"
}
variable "environment" {
  type        = string
  description = "aws tags"

}

