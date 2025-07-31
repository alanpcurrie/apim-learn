# Terraform Infrastructure for Fast & Furious Cars API

This directory contains Terraform configuration for deploying the Fast & Furious Cars API infrastructure on Azure API Management.

## 📁 Directory Structure

```
terraform/
├── main.tf                     # Main Terraform configuration
├── api.tf                      # API-specific resources
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── README.md                   # This file
├── environments/               # Environment-specific configurations
│   ├── dev.tfvars             # Development settings
│   └── prod.tfvars            # Production settings
└── policies/                   # APIM policy templates
    ├── global.xml             # Global API policy
    └── operations/            # Operation-specific policies
        ├── get-cars.xml       # List cars operation policy
        └── get-car-by-id.xml  # Get car by ID operation policy
```

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** - Install and authenticate:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Terraform** - Install Terraform >= 1.0:
   ```bash
   # macOS
   brew install terraform
   
   # Or download from https://www.terraform.io/downloads.html
   ```

3. **Backend Storage** - Create Azure Storage for Terraform state:
   ```bash
   # Create resource group for Terraform backend
   az group create --name rg-terraform-state --location "East US"
   
   # Create storage account
   az storage account create \
     --resource-group rg-terraform-state \
     --name yourtfstate$(date +%s) \
     --sku Standard_LRS \
     --encryption-services blob
   
   # Create container
   az storage container create \
     --name tfstate \
     --account-name yourtfstateXXXXXX
   ```

### 🛠️ Deployment Steps

#### 1. Initialize Terraform

```bash
cd terraform

# Initialize with backend configuration
terraform init \
  -backend-config="resource_group_name=rg-terraform-state" \
  -backend-config="storage_account_name=yourtfstateXXXXXX" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=apim-cars-api.tfstate"
```

#### 2. Plan Deployment

For **development**:
```bash
terraform plan -var-file="environments/dev.tfvars" -out=tfplan-dev
```

For **production**:
```bash
terraform plan -var-file="environments/prod.tfvars" -out=tfplan-prod
```

#### 3. Apply Configuration

```bash
# Development
terraform apply tfplan-dev

# Production
terraform apply tfplan-prod
```

#### 4. Verify Deployment

```bash
# Show outputs
terraform output

# Test API endpoints
curl -X GET "$(terraform output -raw apim_gateway_url)/cars/v1/cars" \
  -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY"
```

## 🔧 Configuration

### Environment Variables

Set these environment variables or update the `.tfvars` files:

| Variable | Description | Required |
|----------|-------------|----------|
| `resource_group_name` | Azure Resource Group name | ✅ |
| `apim_service_name` | APIM service name (globally unique) | ✅ |
| `location` | Azure region | ✅ |
| `publisher_name` | APIM publisher name | ✅ |
| `publisher_email` | APIM publisher email | ✅ |

### Key Configuration Options

#### API Management SKU

- **Development**: `Consumption` (pay-per-call, no uptime SLA)
- **Production**: `Standard_1` or `Premium_1` (dedicated capacity, SLA)

#### Policy Configuration

```hcl
# Rate limiting
rate_limit_calls = 100          # Calls per period
rate_limit_period = 60          # Period in seconds

# CORS settings
cors_allowed_origins = ["*"]    # Allowed origins

# JWT Authentication (optional)
enable_jwt_authentication = true
jwt_issuer = "https://your-auth-provider.com/"
jwt_audience = "https://your-api.com"
```

#### Monitoring Options

```hcl
# Enable diagnostics and monitoring
enable_diagnostics = true
create_application_insights = true
log_analytics_workspace_id = "/subscriptions/.../workspaces/your-workspace"
```

## 📋 Available Resources

The Terraform configuration creates:

### Core Infrastructure
- **Azure Resource Group** - Container for all resources
- **API Management Service** - Main APIM instance
- **System-Assigned Managed Identity** - For secure Azure service access

### API Configuration
- **API Version Set** - Manages API versioning
- **Cars API** - Imported from OpenAPI specification
- **API Policies** - Global and operation-specific policies
- **Product Association** - Links API to products

### Security & Monitoring
- **Global Policy** - Rate limiting, CORS, security headers
- **Operation Policies** - Caching, validation, error handling
- **Application Insights** - Performance monitoring (optional)
- **Diagnostic Settings** - Log Analytics integration (optional)

### Access Management
- **API Product** - Starter product for API access
- **Default Subscription** - For testing (dev only)

## 🔍 Policy Features

### Global Policy (`policies/global.xml`)
- **Rate Limiting** - Configurable per-minute limits
- **CORS Support** - Cross-origin request handling
- **JWT Authentication** - Optional token validation
- **Security Headers** - OWASP recommended headers
- **Mock Responses** - Complete Fast & Furious car data
- **RFC 9457 Error Handling** - Standardized error responses

### Operation Policies
- **Caching** - Configurable response caching
- **Parameter Validation** - Input validation with detailed errors
- **Request/Response Tracing** - Detailed logging
- **Cache Headers** - ETag and cache-control headers

## 📊 Outputs

After successful deployment, Terraform provides:

| Output | Description |
|--------|-------------|
| `apim_gateway_url` | API Gateway URL |
| `cars_api_full_url` | Complete Cars API endpoint |
| `azure_cli_commands` | Useful Azure CLI commands |
| `api_test_commands` | cURL commands for testing |
| `next_steps` | Post-deployment checklist |

## 🧪 Testing

### Get Subscription Keys

```bash
# Using Terraform output
$(terraform output -raw azure_cli_commands | jq -r .get_subscription_keys)

# Manual Azure CLI
az rest --method POST \
  --uri "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$(terraform output -raw resource_group_name)/providers/Microsoft.ApiManagement/service/$(terraform output -raw apim_service_name)/subscriptions/[subscription-id]/listSecrets?api-version=2021-08-01"
```

### Test API Endpoints

```bash
# List all cars
curl -X GET "$(terraform output -raw cars_api_full_url)/cars" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Accept: application/json"

# Get specific car
curl -X GET "$(terraform output -raw cars_api_full_url)/cars/1" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Accept: application/json"

# Test rate limiting
for i in {1..110}; do
  curl -X GET "$(terraform output -raw cars_api_full_url)/cars" \
    -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
    -w "Request $i: %{http_code}\n" -s -o /dev/null
done
```

## 🔄 CI/CD Integration

### GitHub Actions

The project includes a GitHub Actions workflow (`.github/workflows/terraform.yml`) that:

1. **Validates** Terraform configuration
2. **Plans** infrastructure changes
3. **Applies** changes on main branch
4. **Deploys** API configuration using existing Makefile

### Required Secrets

Set these secrets in your GitHub repository:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service Principal client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `TF_STATE_RESOURCE_GROUP` | Terraform state storage RG |
| `TF_STATE_STORAGE_ACCOUNT` | Terraform state storage account |
| `TF_STATE_CONTAINER` | Terraform state container |
| `APIM_RESOURCE_GROUP` | Target resource group |
| `APIM_SERVICE_NAME` | Target APIM service name |
| `AZURE_LOCATION` | Deployment region |
| `PUBLISHER_EMAIL` | APIM publisher email |
| `PUBLISHER_NAME` | APIM publisher name |

## 🛡️ Security Best Practices

### 1. Service Principal Setup

```bash
# Create service principal for CI/CD
az ad sp create-for-rbac --name "sp-terraform-apim" \
  --role "Contributor" \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID" \
  --sdk-auth
```

### 2. Least Privilege Access

- Use specific resource group scopes
- Implement Azure RBAC for fine-grained permissions
- Enable APIM Managed Identity for Azure service access

### 3. Secret Management

- Store sensitive values in Azure Key Vault
- Use GitHub Secrets for CI/CD
- Never commit secrets to version control

### 4. Network Security

```hcl
# For production, consider:
# - Private endpoints
# - VNet integration
# - Custom domains with SSL
# - Web Application Firewall (WAF)
```

## 🔧 Troubleshooting

### Common Issues

1. **APIM Service Name Conflicts**
   ```
   Error: API Management service name must be globally unique
   ```
   Solution: Change `apim_service_name` in your `.tfvars` file

2. **Insufficient Permissions**
   ```
   Error: authorization failed
   ```
   Solution: Ensure your account has `Contributor` role on the subscription

3. **Backend Configuration**
   ```
   Error: Backend configuration changed
   ```
   Solution: Run `terraform init -reconfigure`

4. **Policy Template Errors**
   ```
   Error: Invalid policy XML
   ```
   Solution: Validate XML syntax and template variables

### Debugging Commands

```bash
# Check Terraform state
terraform show

# Validate configuration
terraform validate

# Check Azure CLI authentication
az account show

# APIM service status
az apim show --name YOUR_APIM_NAME --resource-group YOUR_RG
```

## 🚀 Advanced Features

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

```hcl
# Add to main.tf (Premium SKU only)
resource "azurerm_api_management_custom_domain" "gateway" {
  api_management_id = azurerm_api_management.apim.id
  
  gateway {
    host_name    = "api.yourdomain.com"
    certificate  = "path/to/certificate.pfx"
    certificate_password = var.certificate_password
  }
}
```

### Application Insights Integration

```hcl
# Enable in your .tfvars
create_application_insights = true
enable_diagnostics = true
```

## 📚 Additional Resources

- [Azure API Management Documentation](https://docs.microsoft.com/en-us/azure/api-management/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [APIM Policies Reference](https://docs.microsoft.com/en-us/azure/api-management/api-management-policies)
- [RFC 9457 - Problem Details](https://tools.ietf.org/html/rfc9457)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `terraform plan`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.