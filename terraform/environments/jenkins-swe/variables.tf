variable "admin_cidr" {
  description = "Public IPv4 CIDR allowed to connect to the VM over SSH."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 CIDR such as 203.0.113.10/32."
  }
}

variable "admin_ssh_public_key" {
  description = "Public SSH key used for the Jenkins VM administrator."
  type        = string

  validation {
    condition = (
      startswith(var.admin_ssh_public_key, "ssh-ed25519 ") ||
      startswith(var.admin_ssh_public_key, "ssh-rsa ")
    )
    error_message = "admin_ssh_public_key must be an ED25519 or RSA public key."
  }
}

variable "admin_username" {
  description = "Administrator username for the Jenkins VM."
  type        = string
  default     = "azureadmin"
}

variable "vm_size" {
  description = "Azure VM size for the Jenkins controller."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "shutdown_time" {
  description = "Daily VM shutdown time in 24-hour HHmm format."
  type        = string
  default     = "2300"
}

variable "owner" {
  description = "Owner tag applied to Jenkins resources."
  type        = string
  default     = "mouad"
}

variable "expires_on" {
  description = "Review or teardown date applied as a resource tag."
  type        = string
  default     = "2026-12-15"
}
