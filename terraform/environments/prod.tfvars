# Production Environment Configuration
# Fast & Furious Cars API - Azure API Management

environment = "prod"

# Basic Configuration
resource_group_name = "rg-apim-cars-prod"
location            = "East US"
apim_service_name   = "apim-cars-prod"

# Publisher Information (update with your production details)
publisher_name  = "Cars API Production Team"
publisher_email = "api-admin@yourcompany.com"

# API Management SKU - Production tier
apim_sku_name = "Standard_1"

# Additional locations for multi-region deployment (optional)
additional_locations = [
  {
    location = "West US 2"
  }
]

# API Configuration
api_id      = "cars-api"
api_path    = "cars"
api_version = "v1"

# Policy Configuration - Production settings
apply_global_policy        = true
enable_operation_policies  = true
rate_limit_calls          = 100
rate_limit_period         = 60
cors_allowed_origins      = [
  "https://yourdomain.com",
  "https://app.yourdomain.com",
  "https://admin.yourdomain.com"
]
enable_jwt_authentication = true
jwt_issuer               = "https://yourtenant.auth0.com/"
jwt_audience             = "https://api.yourdomain.com"
cache_duration_seconds   = 600

# Product Configuration
starter_product_subscriptions_limit = 1000
create_default_subscription        = false

# Schema Management
manage_schemas = true

# Monitoring Configuration - Full monitoring for production
enable_diagnostics          = true
create_application_insights = true
# log_analytics_workspace_id = "/subscriptions/your-subscription-id/resourcegroups/rg-monitoring/providers/microsoft.operationalinsights/workspaces/law-prod"

# Production tags
tags = {
  Environment = "Production"
  Project     = "Fast-Furious-Cars-API"
  Team        = "API-Platform"
  ManagedBy   = "Terraform"
  CostCenter  = "Platform"
  Purpose     = "Production-API"
  Backup      = "Required"
  Monitoring  = "Critical"
}