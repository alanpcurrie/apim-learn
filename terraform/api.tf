# Cars API Configuration
# This file manages the Fast & Furious Cars API definition and deployment

# Local values for API configuration
locals {
  openapi_spec_path = "${path.root}/openapi/cars-api.yaml"
  api_spec_content  = file(local.openapi_spec_path)
}

# Cars API from OpenAPI specification
resource "azurerm_api_management_api" "cars_api" {
  name                  = var.api_id
  resource_group_name   = azurerm_resource_group.apim.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = "Fast & Furious Cars API"
  path                  = var.api_path
  protocols             = ["https"]
  service_url           = var.api_service_url
  subscription_required = true

  version         = var.api_version
  version_set_id  = azurerm_api_management_api_version_set.cars_api.id

  import {
    content_format = "openapi+json"
    content_value  = local.api_spec_content
  }

  depends_on = [
    azurerm_api_management.apim,
    azurerm_api_management_api_version_set.cars_api
  ]
}

# Add Cars API to Starter Product
resource "azurerm_api_management_product_api" "cars_api_starter" {
  api_name            = azurerm_api_management_api.cars_api.name
  product_id          = azurerm_api_management_product.starter.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name

  depends_on = [
    azurerm_api_management_api.cars_api,
    azurerm_api_management_product.starter
  ]
}

# Operation-specific policies (if enabled)
resource "azurerm_api_management_api_operation_policy" "get_cars" {
  count               = var.enable_operation_policies ? 1 : 0
  api_name            = azurerm_api_management_api.cars_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name
  operation_id        = "get-cars"

  xml_content = templatefile("${path.module}/policies/operations/get-cars.xml", {
    cache_duration = var.cache_duration_seconds
  })

  depends_on = [azurerm_api_management_api.cars_api]
}

resource "azurerm_api_management_api_operation_policy" "get_car_by_id" {
  count               = var.enable_operation_policies ? 1 : 0
  api_name            = azurerm_api_management_api.cars_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name
  operation_id        = "get-car-by-id"

  xml_content = templatefile("${path.module}/policies/operations/get-car-by-id.xml", {
    cache_duration = var.cache_duration_seconds
  })

  depends_on = [azurerm_api_management_api.cars_api]
}

# API Schema Management
resource "azurerm_api_management_api_schema" "car_schema" {
  count               = var.manage_schemas ? 1 : 0
  api_name            = azurerm_api_management_api.cars_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name
  schema_id           = "car-schema"
  content_type        = "application/json"
  value               = file("${path.root}/schemas/car-schema.json")

  depends_on = [azurerm_api_management_api.cars_api]
}

resource "azurerm_api_management_api_schema" "cars_list_schema" {
  count               = var.manage_schemas ? 1 : 0
  api_name            = azurerm_api_management_api.cars_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name
  schema_id           = "cars-list-schema"
  content_type        = "application/json"
  value               = file("${path.root}/schemas/cars-list-schema.json")

  depends_on = [azurerm_api_management_api.cars_api]
}