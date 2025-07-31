# Outputs for Azure API Management Terraform Configuration

# Resource Group Information
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.apim.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.apim.location
}

# API Management Service Information
output "apim_service_name" {
  description = "Name of the API Management service"
  value       = azurerm_api_management.apim.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management service"
  value       = azurerm_api_management.apim.gateway_url
}

output "apim_public_ip_addresses" {
  description = "Public IP addresses of the API Management service"
  value       = azurerm_api_management.apim.public_ip_addresses
}

output "apim_management_api_url" {
  description = "Management API URL of the API Management service"
  value       = azurerm_api_management.apim.management_api_url
}

output "apim_developer_portal_url" {
  description = "Developer portal URL of the API Management service"
  value       = azurerm_api_management.apim.developer_portal_url
}

output "apim_principal_id" {
  description = "Principal ID of the system-assigned managed identity"
  value       = azurerm_api_management.apim.identity[0].principal_id
}

# API Information
output "cars_api_id" {
  description = "ID of the Cars API"
  value       = azurerm_api_management_api.cars_api.name
}

output "cars_api_path" {
  description = "Path of the Cars API"
  value       = azurerm_api_management_api.cars_api.path
}

output "cars_api_version" {
  description = "Version of the Cars API"
  value       = azurerm_api_management_api.cars_api.version
}

output "cars_api_full_url" {
  description = "Full URL to access the Cars API"
  value       = "${azurerm_api_management.apim.gateway_url}/${azurerm_api_management_api.cars_api.path}/${azurerm_api_management_api.cars_api.version}"
}

# Product Information
output "starter_product_id" {
  description = "ID of the starter product"
  value       = azurerm_api_management_product.starter.product_id
}

# Subscription Information
output "default_subscription_id" {
  description = "ID of the default subscription (if created)"
  value       = var.create_default_subscription ? azurerm_api_management_subscription.default[0].id : null
}

output "default_subscription_name" {
  description = "Name of the default subscription (if created)"
  value       = var.create_default_subscription ? azurerm_api_management_subscription.default[0].display_name : null
}

# Application Insights Information (if enabled)
output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key (if created)"
  value       = var.create_application_insights ? azurerm_application_insights.apim[0].instrumentation_key : null
  sensitive   = true
}

output "application_insights_app_id" {
  description = "Application Insights application ID (if created)"
  value       = var.create_application_insights ? azurerm_application_insights.apim[0].app_id : null
}

# Useful commands and information for deployment
output "api_test_commands" {
  description = "Commands to test the deployed API"
  value = {
    list_cars = "curl -X GET '${azurerm_api_management.apim.gateway_url}/${azurerm_api_management_api.cars_api.path}/${azurerm_api_management_api.cars_api.version}/cars' -H 'Ocp-Apim-Subscription-Key: <YOUR_SUBSCRIPTION_KEY>'"
    get_car   = "curl -X GET '${azurerm_api_management.apim.gateway_url}/${azurerm_api_management_api.cars_api.path}/${azurerm_api_management_api.cars_api.version}/cars/1' -H 'Ocp-Apim-Subscription-Key: <YOUR_SUBSCRIPTION_KEY>'"
  }
}

output "azure_cli_commands" {
  description = "Useful Azure CLI commands for managing the API"
  value = {
    get_subscription_keys = "az rest --method POST --uri 'https://management.azure.com/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.apim.name}/providers/Microsoft.ApiManagement/service/${azurerm_api_management.apim.name}/subscriptions/${var.create_default_subscription ? azurerm_api_management_subscription.default[0].id : "<subscription-id>"}/listSecrets?api-version=2021-08-01' --query '{PrimaryKey:primaryKey, SecondaryKey:secondaryKey}'"
    show_api              = "az apim api show --resource-group ${azurerm_resource_group.apim.name} --service-name ${azurerm_api_management.apim.name} --api-id ${azurerm_api_management_api.cars_api.name}"
    list_operations       = "az apim api operation list --resource-group ${azurerm_resource_group.apim.name} --service-name ${azurerm_api_management.apim.name} --api-id ${azurerm_api_management_api.cars_api.name} --output table"
  }
}

# Next Steps Information
output "next_steps" {
  description = "Next steps after Terraform deployment"
  value = [
    "1. Get subscription keys using the Azure CLI command in 'azure_cli_commands.get_subscription_keys'",
    "2. Test the API endpoints using the commands in 'api_test_commands'",
    "3. Configure custom domains and SSL certificates if needed",
    "4. Set up additional monitoring and alerting",
    "5. Configure backup and disaster recovery",
    "6. Review and adjust rate limiting policies",
    "7. Set up CI/CD pipeline for API definition updates"
  ]
}