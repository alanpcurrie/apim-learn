---
title: "Deploy with Terraform Infrastructure-as-Code"
description: "Learn how to deploy and manage the Fast & Furious Cars API infrastructure using Terraform for Azure API Management."
---

# Deploy with Terraform Infrastructure-as-Code

This guide walks you through deploying the Fast & Furious Cars API infrastructure using Terraform, providing a production-ready, version-controlled approach to infrastructure management.

## Overview

The Terraform configuration provides:

- **Infrastructure as Code** - Version-controlled, repeatable deployments
- **Environment Management** - Separate configurations for dev/prod
- **Policy Management** - Automated APIM policy deployment
- **CI/CD Integration** - GitHub Actions workflow included
- **Security Best Practices** - RBAC, managed identities, secure secrets

## Prerequisites

### Required Tools

1. **Azure CLI** (authenticated)
2. **Terraform** (>= 1.0)
3. **Git** (for version control)

### Azure Setup

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Create storage for Terraform state
az group create --name rg-terraform-state --location "East US"
az storage account create \
  --resource-group rg-terraform-state \
  --name tfstate$(date +%s) \
  --sku Standard_LRS
az storage container create \
  --name tfstate \
  --account-name tfstateXXXXXX
```

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform

terraform init \
  -backend-config="resource_group_name=rg-terraform-state" \
  -backend-config="storage_account_name=tfstateXXXXXX" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=apim-cars-api.tfstate"
```

### 2. Configure Environment

Edit `terraform/environments/dev.tfvars`:

```hcl
# Update with your values
resource_group_name = "rg-apim-cars-dev"
apim_service_name   = "apim-cars-dev-yourname"
publisher_name      = "Your Name"
publisher_email     = "your-email@example.com"
```

### 3. Deploy Infrastructure

```bash
# Plan deployment
terraform plan -var-file="environments/dev.tfvars" -out=tfplan

# Apply changes
terraform apply tfplan
```

### 4. Verify Deployment

```bash
# Get API URL
terraform output apim_gateway_url

# Get test commands
terraform output api_test_commands
```

## Configuration Guide

### Environment Files

The configuration supports multiple environments through `.tfvars` files:

#### Development (`environments/dev.tfvars`)

```hcl
environment = "dev"
apim_sku_name = "Consumption"              # Pay-per-call
rate_limit_calls = 1000                    # Higher limits for testing
create_default_subscription = true         # Auto-create test subscription
enable_jwt_authentication = false         # Disabled for easier testing
```

#### Production (`environments/prod.tfvars`)

```hcl
environment = "prod"
apim_sku_name = "Standard_1"               # Dedicated capacity
rate_limit_calls = 100                     # Production limits
create_default_subscription = false        # Manual subscription management
enable_jwt_authentication = true          # Security enabled
cors_allowed_origins = [                   # Restricted CORS
  "https://yourdomain.com",
  "https://app.yourdomain.com"
]
```

### Key Configuration Options

| Setting | Development | Production | Description |
|---------|-------------|------------|-------------|
| `apim_sku_name` | `Consumption` | `Standard_1` | APIM service tier |
| `rate_limit_calls` | `1000` | `100` | API rate limiting |
| `cors_allowed_origins` | `["*"]` | `["https://yourdomain.com"]` | CORS configuration |
| `enable_jwt_authentication` | `false` | `true` | JWT token validation |
| `create_application_insights` | `true` | `true` | Monitoring setup |

## Policy Management

### Global Policy Features

The Terraform configuration includes a comprehensive global policy with:

- **Rate Limiting** - Configurable per-minute limits
- **CORS Support** - Cross-origin request handling  
- **Security Headers** - OWASP recommended headers
- **Mock Responses** - Complete Fast & Furious car data
- **RFC 9457 Error Handling** - Standardized error responses
- **JWT Authentication** - Optional token validation

### Operation-Specific Policies

#### Caching Policy

```xml
<!-- Automatically applied to GET operations -->
<cache-lookup vary-by-developer="false" />
<cache-store duration="300" />
```

#### Parameter Validation

```xml
<!-- Validates query parameters with detailed error responses -->
<choose>
  <when condition="@(!int.TryParse(context.Request.Url.Query['page'], out int page) || page < 1)">
    <return-response>
      <set-status code="400" reason="Bad Request" />
      <set-body>RFC 9457 compliant error response</set-body>
    </return-response>
  </when>
</choose>
```

## CI/CD Integration

### GitHub Actions Workflow

The included workflow (`.github/workflows/terraform.yml`) provides:

1. **Automatic Validation** - On pull requests
2. **Infrastructure Planning** - Shows planned changes
3. **Automated Deployment** - On main branch pushes
4. **API Configuration** - Deploys OpenAPI spec and policies

### Required Secrets

Configure these secrets in your GitHub repository:

```bash
# Azure Authentication
AZURE_CLIENT_ID
AZURE_TENANT_ID  
AZURE_SUBSCRIPTION_ID

# Terraform Backend
TF_STATE_RESOURCE_GROUP
TF_STATE_STORAGE_ACCOUNT
TF_STATE_CONTAINER

# Deployment Configuration
APIM_RESOURCE_GROUP
APIM_SERVICE_NAME
AZURE_LOCATION
PUBLISHER_EMAIL
PUBLISHER_NAME
```

### Service Principal Setup

```bash
# Create service principal for CI/CD
az ad sp create-for-rbac --name "sp-terraform-apim" \
  --role "Contributor" \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --sdk-auth
```

## Advanced Configuration

### Multi-Region Deployment

For production high availability:

```hcl
# In prod.tfvars
apim_sku_name = "Premium_1"
additional_locations = [
  { location = "West US 2" },
  { location = "West Europe" }
]
```

### Custom Domains

Enable custom domains (Premium SKU only):

```hcl
# SSL certificate required
enable_custom_domain = true
gateway_custom_domain = "api.yourdomain.com"
certificate_path = "path/to/certificate.pfx"
```

### Monitoring Integration

Full monitoring setup:

```hcl
enable_diagnostics = true
create_application_insights = true
log_analytics_workspace_id = "/subscriptions/.../workspaces/your-workspace"
```

## Testing Your Deployment

### Get Subscription Keys

```bash
# Using Terraform output
eval $(terraform output -raw azure_cli_commands | jq -r .get_subscription_keys)
```

### Test API Endpoints

```bash
# Get the API URL
API_URL=$(terraform output -raw cars_api_full_url)
SUBSCRIPTION_KEY="your-key-here"

# List all cars
curl -X GET "$API_URL/cars" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Accept: application/json"

# Get specific car
curl -X GET "$API_URL/cars/1" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Accept: application/json"
```

### Test Rate Limiting

```bash
# Generate multiple requests to test rate limiting
for i in {1..110}; do
  curl -X GET "$API_URL/cars" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -w "Request $i: %{http_code}\n" -s -o /dev/null
done
```

## Troubleshooting

### Common Issues

#### APIM Service Name Conflicts

```bash
# Error: API Management service name must be globally unique
# Solution: Update apim_service_name in your .tfvars file
```

#### Insufficient Permissions

```bash
# Error: authorization failed  
# Solution: Ensure Contributor role on subscription
az role assignment create \
  --assignee "your-user@domain.com" \
  --role "Contributor" \
  --scope "/subscriptions/your-subscription-id"
```

#### Backend Configuration Changes

```bash
# Error: Backend configuration changed
# Solution: Reinitialize Terraform
terraform init -reconfigure
```

### Debugging Commands

```bash
# Validate Terraform configuration
terraform validate

# Show current state
terraform show

# Check APIM service status
az apim show --name YOUR_APIM_NAME --resource-group YOUR_RG

# View detailed logs
terraform apply -auto-approve -var-file="environments/dev.tfvars" -no-color 2>&1 | tee terraform.log
```

## Cost Management

### SKU Comparison

| SKU | Cost Model | Use Case | SLA |
|-----|------------|----------|-----|
| `Consumption` | Pay-per-call | Development, testing | None |
| `Developer` | Fixed monthly | Development | None |
| `Basic` | Fixed monthly | Small production | 99.95% |
| `Standard` | Fixed monthly | Production | 99.95% |
| `Premium` | Fixed monthly | Enterprise | 99.95% |

### Cost Optimization Tips

1. **Use Consumption tier** for development
2. **Enable caching** to reduce backend calls
3. **Monitor usage** with Application Insights
4. **Right-size** production SKU based on traffic
5. **Consider reserved instances** for predictable workloads

## Security Best Practices

### Infrastructure Security

- **Use Managed Identities** for Azure service access
- **Enable diagnostic logging** for audit trails
- **Implement least privilege** RBAC policies
- **Store secrets** in Azure Key Vault
- **Enable network restrictions** for production

### API Security

- **Enable JWT authentication** for production
- **Configure CORS** restrictively
- **Implement rate limiting** to prevent abuse
- **Use HTTPS only** with proper certificates
- **Monitor for anomalies** with Application Insights

## Migration from Makefile

If you're currently using the Makefile approach, here's how to migrate:

### 1. Export Current Configuration

```bash
# Export existing API
make export-api

# Save current environment variables
cp .env .env.backup
```

### 2. Import to Terraform

```bash
# Initialize Terraform
cd terraform
terraform init

# Import existing resources (optional)
terraform import azurerm_resource_group.apim /subscriptions/SUB_ID/resourceGroups/RG_NAME
terraform import azurerm_api_management.apim /subscriptions/SUB_ID/resourceGroups/RG_NAME/providers/Microsoft.ApiManagement/service/APIM_NAME
```

### 3. Validate Configuration

```bash
# Plan should show minimal changes
terraform plan -var-file="environments/dev.tfvars"
```

## Next Steps

After successful Terraform deployment:

1. **Configure custom domains** and SSL certificates
2. **Set up monitoring** and alerting
3. **Implement backup** and disaster recovery
4. **Configure CI/CD** pipeline for API updates
5. **Review security** settings and policies
6. **Set up cost** monitoring and budgets
7. **Document** your specific customizations

## Support and Resources

- [Terraform Configuration Files](../reference/terraform-reference.md)
- [Azure API Management Documentation](https://docs.microsoft.com/en-us/azure/api-management/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Project GitHub Repository](https://github.com/your-org/apim-learn)

---

> 💡 **Pro Tip**: Start with the development environment to familiarize yourself with the Terraform workflow before deploying to production.