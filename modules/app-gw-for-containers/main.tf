data "azurerm_client_config" "current" {}

resource "azurerm_application_load_balancer" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags                         = var.tags
}

resource "azurerm_application_load_balancer_frontend" "this" {
  name                         = var.frontend_name
  application_load_balancer_id = azurerm_application_load_balancer.this.id

  tags                         = var.tags
  depends_on = [
    time_sleep.wait_for_agfc
  ]
}


resource "azurerm_application_load_balancer_subnet_association" "this" {
  name                         = var.association_name
  application_load_balancer_id = azurerm_application_load_balancer.this.id
  subnet_id                    = var.association_subnet_id
  tags                         = var.tags
  depends_on = [
    time_sleep.wait_for_agfc
  ]
}

resource "time_sleep" "wait_for_agfc" {
  depends_on = [
    azurerm_application_load_balancer.this
  ]

  create_duration = "90s"
}


resource "azurerm_user_assigned_identity" "alb_controller" {
  name                = var.alb_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "helm_release" "alb_controller" {
  name       = "alb-controller"
  repository = "oci://mcr.microsoft.com/application-lb/charts"
  chart      = "alb-controller"
  version    = "1.10.28"

  namespace        = var.alb_controller_namespace
  create_namespace = true

  set = [
    {
      name  = "albController.namespace"
      value = var.alb_controller_namespace
    },
    {
      name  = "albController.podIdentity.clientID"
      value = azurerm_user_assigned_identity.alb_controller.client_id
    }
  ]
}

resource "azurerm_federated_identity_credential" "alb_controller" {
  name                = "aksfic"
  parent_id           = azurerm_user_assigned_identity.alb_controller.id
  resource_group_name = var.resource_group_name

  issuer   = var.aks_oidc_issuer_url
  subject  = "system:serviceaccount:${var.alb_controller_namespace}:${var.alb_controller_service_account_name}"
  audience = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "alb_config_manager_on_rg" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "AppGw for Containers Configuration Manager"
  principal_id         = azurerm_user_assigned_identity.alb_controller.principal_id
}

resource "azurerm_role_assignment" "alb_network_contributor_on_subnet" {
  scope                = var.association_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.alb_controller.principal_id
}
