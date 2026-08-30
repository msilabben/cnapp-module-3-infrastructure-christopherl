resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  sku_name = var.sku_name

  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  purge_protection_enabled        = var.purge_protection_enabled
  soft_delete_retention_days      = var.soft_delete_retention_days

  # Prefer RBAC over Key Vault access policies.
  rbac_authorization_enabled = true

  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    default_action = var.network_default_action
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "administrators" {
  for_each = toset(var.administrator_principal_ids)

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}


resource "azurerm_role_assignment" "secrets_users" {
  for_each = toset(var.secrets_user_principal_ids)

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}


resource "azurerm_role_assignment" "secrets_officers" {
  for_each = toset(var.secrets_officer_principal_ids)

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
  principal_type       = "User"
}
