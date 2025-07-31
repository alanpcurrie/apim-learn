# Development Environment Configuration
# Fast & Furious Cars API - Azure API Management

environment = "dev"

# Basic Configuration
resource_group_name = "rg-apim-cars-dev"
location            = "East US"
apim_service_name   = "apim-cars-dev"

# Publisher Information (update with your details)
publisher_name  = "Cars API Development Team"
publisher_email = "dev-team@example.com"

# API Management SKU
apim_sku_name = "Consumption"

# API Configuration
api_id      = "cars-api"
api_path    = "cars"
api_version = "v1"

# Policy Configuration
apply_global_policy        = true
enable_operation_policies  = true
rate_limit_calls          = 1000
rate_limit_period         = 60
cors_allowed_origins      = ["*"]
enable_jwt_authentication = false
cache_duration_seconds    = 300

# Product Configuration
starter_product_subscriptions_limit = 50
create_default_subscription        = true

# Schema Management
manage_schemas = true

# Monitoring Configuration
enable_diagnostics           = false
create_application_insights  = true

# Environment-specific tags
tags = {
  Environment = "Development"
  Project     = "Fast-Furious-Cars-API"
  Team        = "API-Development"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering"
  Purpose     = "API-Development-Testing"
}