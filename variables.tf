variable "resource_group_name" {
  default = "rg-hello-world"
}

variable "location" {
  default = "East Asia"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}
