variable "ami" {
  description = "ubuntu 20.04"
  type        = string
  default     = "ami-0778521d914d23bc1"
}

variable "instance_type" {
  type    = string
  default = "t2.medium"
}

variable "name" {
  type    = string
  default = "Rajesh"
}