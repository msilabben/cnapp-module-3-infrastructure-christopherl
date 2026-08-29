data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

locals {
  environments = toset(["dev", "prod"])

  # Storage accounts must be globally unique, lowercase, no hyphens, and max 24 chars.
  storage_prefix = replace(var.name_prefix, "-", "")

  identity_resource_group_name = "rg-${var.name_prefix}-github-oidc"
  state_resource_group_name    = "rg-${var.name_prefix}-tfstate"
  state_storage_account_name   = substr("sttf${local.storage_prefix}", 0, 24)

  environment_resource_group_names = {
    for env in local.environments :
    env => "rg-${var.name_prefix}-${env}"
  }

  aks_resource_group_names = {
    for env in local.environments :
    env => "${local.environment_resource_group_names[env]}-aks"
  }

  plan_identity_names = {
    for env in local.environments :
    env => "id-${var.name_prefix}-${env}-plan"
  }

  apply_identity_names = {
    for env in local.environments :
    env => "id-${var.name_prefix}-${env}-apply"
  }

  state_container_names = {
    for env in local.environments :
    env => "tfstate-${env}"
  }

  common_tags = merge(var.tags, {
    instance   = var.name_prefix
    managed_by = "terraform"
  })
}

resource "azurerm_resource_group" "identity" {
  name     = local.identity_resource_group_name
  location = var.location

  tags = local.common_tags
}

resource "azurerm_resource_group" "state" {
  name     = local.state_resource_group_name
  location = var.location

  tags = local.common_tags
}

resource "azurerm_storage_account" "state" {
  name                     = local.state_storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = local.common_tags
}

resource "azurerm_storage_container" "state" {
  for_each = local.environments

  name                  = local.state_container_names[each.key]
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_resource_group" "environment" {
  for_each = local.environments

  name     = local.environment_resource_group_names[each.key]
  location = var.location

  tags = merge(local.common_tags, {
    environment = each.key
  })
}


resource "azurerm_resource_group" "environment_aks" {
  for_each = local.environments

  name     = local.aks_resource_group_names[each.key]
  location = var.location

  tags = merge(local.common_tags, {
    environment = each.key
  })
}


resource "azurerm_user_assigned_identity" "plan" {
  for_each = local.environments

  name                = local.plan_identity_names[each.key]
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name

  tags = merge(local.common_tags, {
    environment = each.key
    purpose     = "plan"
  })
}

resource "azurerm_user_assigned_identity" "apply" {
  for_each = local.environments

  name                = local.apply_identity_names[each.key]
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name

  tags = merge(local.common_tags, {
    environment = each.key
    purpose     = "apply"
  })
}

# PR plans: allow pull_request workflows to assume the dev plan identity only.
# This identity should be read-only and should not be able to apply changes.
resource "azurerm_federated_identity_credential" "dev_plan_pull_request" {
  name                = "github-${var.github_repository}-dev-plan-pr"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.plan["dev"].id

  audience = ["api://AzureADTokenExchange"]
  issuer   = "https://token.actions.githubusercontent.com"
  subject  = "repo:${var.github_organization}@158168931/${var.github_repository}@1350597621:pull_request"
}

# Environment plans: useful for manual/main-branch plans if you want an environment-scoped read-only identity.
resource "azurerm_federated_identity_credential" "plan_environment" {
  for_each = local.environments

  name                = "github-${var.github_repository}-${each.key}-plan"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.plan[each.key].id

  audience = ["api://AzureADTokenExchange"]
  issuer   = "https://token.actions.githubusercontent.com"
  subject  = "repo:${var.github_organization}@158168931/${var.github_repository}@1350597621:environment:${each.key}"
}

# Applies: environment-scoped FICs mapped to the write-capable identities.
resource "azurerm_federated_identity_credential" "apply_environment" {
  for_each = local.environments

  name                = "github-${var.github_repository}-${each.key}-apply"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.apply[each.key].id

  audience = ["api://AzureADTokenExchange"]
  issuer   = "https://token.actions.githubusercontent.com"
  subject  = "repo:${var.github_organization}@158168931/${var.github_repository}@1350597621:environment:${each.key}"
}

resource "azurerm_role_assignment" "plan_subscription_reader" {
  for_each = local.environments

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan[each.key].principal_id
}

resource "azurerm_role_assignment" "apply_contributor" {
  for_each = local.environments

  scope                = azurerm_resource_group.environment[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
}

resource "azurerm_role_assignment" "apply_rbac_administrator" {
  for_each = local.environments

  scope                = azurerm_resource_group.environment[each.key].id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
}

resource "azurerm_role_assignment" "plan_reader_aks" {
  for_each = local.environments

  scope                = azurerm_resource_group.environment_aks[each.key].id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan[each.key].principal_id
}

resource "azurerm_role_assignment" "apply_contributor_aks" {
  for_each = local.environments

  scope                = azurerm_resource_group.environment_aks[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
}

resource "azurerm_role_assignment" "apply_rbac_administrator_aks" {
  for_each = local.environments

  scope                = azurerm_resource_group.environment_aks[each.key].id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
}

resource "azurerm_role_assignment" "plan_state_reader" {
  for_each = local.environments

  scope                = "${azurerm_storage_account.state.id}/blobServices/default/containers/${azurerm_storage_container.state[each.key].name}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.plan[each.key].principal_id
}

resource "azurerm_role_assignment" "dev_plan_aks_cluster_user" {
  scope                = azurerm_resource_group.environment_aks["dev"].id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_user_assigned_identity.plan["dev"].principal_id
}

resource "azurerm_role_assignment" "apply_state_blob_data_owner" {
  for_each = local.environments

  scope                = "${azurerm_storage_account.state.id}/blobServices/default/containers/${azurerm_storage_container.state[each.key].name}"
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
}

resource "azurerm_role_assignment" "apply_subscription_reader" {
  for_each = local.environments

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
}

resource "azurerm_role_assignment" "apply_subscription_rbac_administrator" {
  for_each = local.environments

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
}
