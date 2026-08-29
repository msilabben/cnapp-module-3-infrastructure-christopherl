variable "location" {
  description = "Azure region for resources."
  type        = string
  default     = "westeurope"
}

variable "name_prefix" {
  description = "Prefix to be used for resource creation."
  type        = string
}

variable "tags" {
  description = "Common tags applied to resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "cnapp-module-3-infrastructure-christopherl"
    owner      = "christopherl"
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "key_vault_administrator_principal_ids" {
  description = "Principal IDs that should administer the Key Vault."
  type        = list(string)
  default     = []
}

variable "key_vault_secrets_user_principal_ids" {
  description = "Principal IDs that should read secrets from the Key Vault."
  type        = list(string)
  default     = []
}

variable "aks_kubernetes_version" {
  description = "AKS Kubernetes version. Null lets Azure choose the default."
  type        = string
  default     = null
}

variable "aks_node_count" {
  description = "Number of AKS nodes."
  type        = number
  default     = 2
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "acr_sku" {
  type        = string
  description = "SKU for the Azure Container Registry."
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "The acr_sku value must be Basic, Standard, or Premium."
  }
}

variable "acr_admin_enabled" {
  type        = bool
  description = "Whether the Azure Container Registry admin user is enabled."
  default     = false
}


variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
}

variable "aks_subnet_name" {
  description = "Name of the AKS subnet."
  type        = string
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS subnet."
  type        = list(string)
}

variable "agfc_subnet_name" {
  description = "Name of the Application Gateway for Containers subnet."
  type        = string
}

variable "agfc_subnet_address_prefixes" {
  description = "Address prefixes for the Application Gateway for Containers subnet."
  type        = list(string)
}

variable "alb_controller_namespace" {
  description = "Namespace where ALB Controller will be installed."
  type        = string
  default     = "azure-alb-system"
}

variable "github_organization" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name."
  type        = string
}

variable "github_environments" {
  description = "GitHub environments trusted by the managed identity."
  type        = set(string)
  default     = ["dev", "prod"]
}

variable "role_definition_name" {
  description = "Azure RBAC role assigned to the managed identity. Narrow the scope/role for stricter setups."
  type        = string
  default     = "Contributor"
}

