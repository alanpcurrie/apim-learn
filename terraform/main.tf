terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.9"
    }
  }

  backend "azurerm" {
    # Backend configuration will be provided via command line
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "apim" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# API Management Service
resource "azurerm_api_management" "apim" {
  name                = var.apim_service_name
  location            = azurerm_resource_group.apim.location
  resource_group_name = azurerm_resource_group.apim.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  sku_name = var.apim_sku_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  # Configuration for consumption tier
  dynamic "additional_location" {
    for_each = var.apim_sku_name == "Consumption" ? [] : var.additional_locations
    content {
      location = additional_location.value.location
    }
  }
}

# API Version Set for Cars API
resource "azurerm_api_management_api_version_set" "cars_api" {
  name                = "${var.api_id}-version-set"
  resource_group_name = azurerm_resource_group.apim.name
  api_management_name = azurerm_api_management.apim.name
  display_name        = "Fast & Furious Cars API Version Set"
  description         = "Version set for Fast & Furious Cars API"
  versioning_scheme   = "Segment"
}

# Global API Policy
resource "azurerm_api_management_api_policy" "cars_api_global" {
  count               = var.apply_global_policy ? 1 : 0
  api_name            = azurerm_api_management_api.cars_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name

  xml_content = templatefile("${path.module}/policies/global.xml", {
    rate_limit_calls    = var.rate_limit_calls
    rate_limit_period   = var.rate_limit_period
    cors_allowed_origins = join(",", var.cors_allowed_origins)
    enable_jwt_auth     = var.enable_jwt_authentication
    jwt_issuer          = var.jwt_issuer
    jwt_audience        = var.jwt_audience
  })

  depends_on = [azurerm_api_management_api.cars_api]
}

# Diagnostic Settings for APIM
resource "azurerm_monitor_diagnostic_setting" "apim" {
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "apim-diagnostics"
  target_resource_id         = azurerm_api_management.apim.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_log {
    category = "WebSocketConnectionLogs"
  }

  metric {
    category = "Gateway Requests"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}

# Application Insights for APIM (optional)
resource "azurerm_application_insights" "apim" {
  count               = var.create_application_insights ? 1 : 0
  name                = "${var.apim_service_name}-insights"
  location            = azurerm_resource_group.apim.location
  resource_group_name = azurerm_resource_group.apim.name
  application_type    = "web"

  tags = var.tags
}

# APIM Logger for Application Insights
resource "azurerm_api_management_logger" "apim_insights" {
  count               = var.create_application_insights ? 1 : 0
  name                = "apim-insights-logger"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name

  application_insights {
    instrumentation_key = azurerm_application_insights.apim[0].instrumentation_key
  }
}

# API Management Product (Starter)
resource "azurerm_api_management_product" "starter" {
  product_id            = "starter"
  api_management_name   = azurerm_api_management.apim.name
  resource_group_name   = azurerm_resource_group.apim.name
  display_name          = "Starter"
  description           = "Starter product for Fast & Furious Cars API"
  subscription_required = true
  approval_required     = false
  published             = true

  subscriptions_limit = var.starter_product_subscriptions_limit
}

# Default subscription for testing
resource "azurerm_api_management_subscription" "default" {
  count               = var.create_default_subscription ? 1 : 0
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name
  product_id          = azurerm_api_management_product.starter.product_id
  display_name        = "Default Cars API Subscription"
  state               = "active"
}