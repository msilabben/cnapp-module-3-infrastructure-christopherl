data "azurerm_resource_group" "environment" {
  name = "rg-${var.name_prefix}-dev"
}

data "azurerm_resource_group" "environment_aks" {
  name = "rg-${var.name_prefix}-dev-aks"
}

resource "azurerm_user_assigned_identity" "github_actions_deploy" {
  name                = "${var.name}-deploy"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "github_actions_push" {
  name                = "${var.name}-push"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github_environment_deploy" {
  for_each = toset(var.github_environments)

  name                = "github-${var.github_repository}-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.github_actions_deploy.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = "https://token.actions.githubusercontent.com"
  subject  = "repo:${var.github_organization}@158168931/${var.github_repository}@1350740006:environment:${each.key}"
}

resource "azurerm_federated_identity_credential" "github_environment_push" {
  for_each = toset(var.github_environments)

  name                = "github-${var.github_repository}-${each.key}-push"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.github_actions_push.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = "https://token.actions.githubusercontent.com"
  subject  = "repo:${var.github_organization}@158168931/${var.github_repository}@1350740006:environment:${each.key}"
}

locals {
  role_assignment_scopes = {
    environment     = data.azurerm_resource_group.environment.id
    environment_aks = data.azurerm_resource_group.environment_aks.id
  }
}

resource "azurerm_role_assignment" "terraform_resource_group" {
  for_each = local.role_assignment_scopes

  scope                = each.value
  role_definition_name = var.role_definition_name
  principal_id         = azurerm_user_assigned_identity.github_actions_deploy.principal_id
}


