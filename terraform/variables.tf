# Variables for Azure API Management Terraform Configuration

# Basic Configuration
variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  validation {
    condition     = length(var.resource_group_name) > 0 && length(var.resource_group_name) <= 64
    error_message = "Resource group name must be between 1 and 64 characters."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
  validation {
    condition = contains([
      "East US", "East US 2", "West US", "West US 2", "West US 3",
      "Central US", "North Central US", "South Central US", "West Central US",
      "Canada Central", "Canada East", "Brazil South", "UK South", "UK West",
      "West Europe", "North Europe", "France Central", "Germany West Central",
      "Norway East", "Switzerland North", "Sweden Central",
      "Australia East", "Australia Southeast", "Australia Central",
      "Japan East", "Japan West", "Korea Central", "Korea South",
      "Southeast Asia", "East Asia", "South India", "Central India", "West India"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "Fast-Furious-Cars-API"
    ManagedBy   = "Terraform"
  }
}

# API Management Configuration
variable "apim_service_name" {
  description = "Name of the API Management service"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,48}[a-z0-9]$", var.apim_service_name))
    error_message = "APIM service name must be 1-50 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "publisher_name" {
  description = "Publisher name for the API Management service"
  type        = string
  validation {
    condition     = length(var.publisher_name) > 0 && length(var.publisher_name) <= 100
    error_message = "Publisher name must be between 1 and 100 characters."
  }
}

variable "publisher_email" {
  description = "Publisher email for the API Management service"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.publisher_email))
    error_message = "Publisher email must be a valid email address."
  }
}

variable "apim_sku_name" {
  description = "SKU name for the API Management service"
  type        = string
  default     = "Consumption"
  validation {
    condition = contains([
      "Consumption",
      "Developer_1", "Basic_1", "Basic_2",
      "Standard_1", "Standard_2",
      "Premium_1", "Premium_2", "Premium_3", "Premium_4", "Premium_5", "Premium_6"
    ], var.apim_sku_name)
    error_message = "SKU name must be a valid API Management SKU."
  }
}

variable "additional_locations" {
  description = "Additional locations for multi-region deployment (Premium SKU only)"
  type = list(object({
    location = string
  }))
  default = []
}

# API Configuration
variable "api_id" {
  description = "ID of the Cars API"
  type        = string
  default     = "cars-api"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.api_id))
    error_message = "API ID must start with a letter, end with a letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "api_path" {
  description = "Path for the Cars API"
  type        = string
  default     = "cars"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-/]*[a-z0-9]$", var.api_path))
    error_message = "API path must contain only lowercase letters, numbers, hyphens, and forward slashes."
  }
}

variable "api_version" {
  description = "Version of the Cars API"
  type        = string
  default     = "v1"
  validation {
    condition     = can(regex("^v[0-9]+$", var.api_version))
    error_message = "API version must follow the pattern 'v1', 'v2', etc."
  }
}

variable "api_service_url" {
  description = "Backend service URL for the API (optional for mock APIs)"
  type        = string
  default     = null
}

# Policy Configuration
variable "apply_global_policy" {
  description = "Whether to apply the global API policy"
  type        = bool
  default     = true
}

variable "enable_operation_policies" {
  description = "Whether to enable operation-specific policies"
  type        = bool
  default     = false
}

variable "rate_limit_calls" {
  description = "Number of calls allowed per rate limit period"
  type        = number
  default     = 100
  validation {
    condition     = var.rate_limit_calls > 0 && var.rate_limit_calls <= 10000
    error_message = "Rate limit calls must be between 1 and 10000."
  }
}

variable "rate_limit_period" {
  description = "Rate limit period in seconds"
  type        = number
  default     = 60
  validation {
    condition     = var.rate_limit_period >= 1 && var.rate_limit_period <= 3600
    error_message = "Rate limit period must be between 1 and 3600 seconds."
  }
}

variable "cors_allowed_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "enable_jwt_authentication" {
  description = "Whether to enable JWT authentication"
  type        = bool
  default     = false
}

variable "jwt_issuer" {
  description = "JWT token issuer (required if JWT auth is enabled)"
  type        = string
  default     = ""
}

variable "jwt_audience" {
  description = "JWT token audience (required if JWT auth is enabled)"
  type        = string
  default     = ""
}

variable "cache_duration_seconds" {
  description = "Cache duration for API responses in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.cache_duration_seconds >= 0 && var.cache_duration_seconds <= 3600
    error_message = "Cache duration must be between 0 and 3600 seconds."
  }
}

# Product Configuration
variable "starter_product_subscriptions_limit" {
  description = "Maximum number of subscriptions for the starter product"
  type        = number
  default     = 100
  validation {
    condition     = var.starter_product_subscriptions_limit > 0
    error_message = "Subscriptions limit must be greater than 0."
  }
}

variable "create_default_subscription" {
  description = "Whether to create a default subscription for testing"
  type        = bool
  default     = true
}

# Schema Management
variable "manage_schemas" {
  description = "Whether to manage API schemas via Terraform"
  type        = bool
  default     = true
}

# Monitoring and Diagnostics
variable "enable_diagnostics" {
  description = "Whether to enable diagnostic settings"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics (required if diagnostics enabled)"
  type        = string
  default     = null
}

variable "create_application_insights" {
  description = "Whether to create Application Insights for monitoring"
  type        = bool
  default     = false
}

# Environment-specific overrides
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}