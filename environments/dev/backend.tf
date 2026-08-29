terraform {
  backend "azurerm" {
    resource_group_name  = "rg-christopherl-tfstate"
    storage_account_name = "sttfchristopherl"
    container_name       = "tfstate-dev"
    key                  = "dev.terraform.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}
