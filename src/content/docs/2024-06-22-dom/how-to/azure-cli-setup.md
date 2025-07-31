---
title: "Azure CLI Setup and Authentication"
description: "Complete guide to installing, configuring, and troubleshooting Azure CLI for API Management operations."
---

This guide covers everything you need to know about setting up and using Azure CLI for Azure API Management operations.

## Installation

### macOS

```bash
# Using Homebrew (recommended)
brew update && brew install azure-cli

# Verify installation
az --version
```

### Windows

```bash
# Using Chocolatey (recommended)
choco install azure-cli

# Alternative: Download MSI installer from Microsoft
# https://docs.microsoft.com/cli/azure/install-azure-cli-windows
```

### Linux (Ubuntu/Debian)

```bash
# Install via Microsoft repository
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verify installation
az --version
```

### Docker (All Platforms)

```bash
# Run Azure CLI in Docker container
docker run -it mcr.microsoft.com/azure-cli:latest

# For persistent login, mount a volume
docker run -it -v ~/.azure:/root/.azure mcr.microsoft.com/azure-cli:latest
```

## Authentication Methods

### Interactive Login (Recommended for Development)

```bash
# Opens browser for authentication
az login

# Login to specific tenant
az login --tenant YOUR_TENANT_ID

# Use device code (for remote/headless systems)
az login --use-device-code
```

### Service Principal Authentication (CI/CD)

Create a service principal for automated deployments:

```bash
# Create service principal
az ad sp create-for-rbac --name "apim-deployment-sp" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Login with service principal
az login --service-principal \
  --username APP_ID \
  --password PASSWORD \
  --tenant TENANT_ID
```

### Managed Identity (Azure Resources)

For Azure VMs or Azure DevOps:

```bash
# Login using managed identity
az login --identity

# Use user-assigned managed identity
az login --identity --username USER_ASSIGNED_IDENTITY_CLIENT_ID
```

## Account Management

### Check Current Account

```bash
# Show current account and subscription
az account show

# List all available subscriptions
az account list --output table

# Show account in specific format
az account show --query "{subscriptionId:id, subscriptionName:name, user:user.name}" --output table
```

### Switch Subscriptions

```bash
# Set default subscription
az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"

# Verify the change
az account show --query "name" --output tsv
```

### Logout

```bash
# Logout current user
az logout

# Clear all cached credentials
az account clear
```

## Configuration

### Set Default Values

```bash
# Set default resource group
az configure --defaults group=rg-apim-demo

# Set default location
az configure --defaults location=eastus

# View current defaults
az configure --list-defaults
```

### Output Formatting

```bash
# Set default output format
az configure --defaults output=table

# Available formats: json, jsonc, yaml, yamlc, table, tsv, none
# Use --output parameter to override per command
az account show --output yaml
```

### Enable Auto-Completion

```bash
# Bash
echo 'source /path/to/az.completion' >> ~/.bashrc

# Zsh
echo 'source /path/to/az.completion' >> ~/.zshrc

# PowerShell
# Add to PowerShell profile
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    az
    Get-Content $completion_file
    Remove-Item $completion_file
}
```

## Troubleshooting

### Common Authentication Issues

#### "Please run 'az login' to setup account"

```bash
# Check if logged in
az account show

# If not logged in
az login

# If logged in but still getting error
az account clear
az login
```

#### Token Expired

```bash
# Refresh authentication
az account get-access-token --resource https://management.azure.com/

# If expired, re-authenticate
az logout
az login
```

#### Wrong Subscription

```bash
# List subscriptions
az account list --output table

# Switch to correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Permission Issues

#### Insufficient Permissions

```bash
# Check current user permissions
az role assignment list --assignee $(az account show --query user.name --output tsv) --output table

# Check specific resource permissions
az role assignment list --scope /subscriptions/SUBSCRIPTION_ID/resourceGroups/RG_NAME --output table
```

Required permissions for APIM operations:
- **API Management Service Contributor** - Full APIM access
- **Contributor** - Resource creation/modification
- **Reader** - Read-only access

### Network and Connectivity

#### Proxy Configuration

```bash
# Set HTTP proxy
az configure --defaults core.proxy_url=http://proxy.company.com:8080

# For HTTPS proxy with authentication
az configure --defaults core.proxy_url=https://username:password@proxy.company.com:8080

# Disable SSL verification (not recommended for production)
az configure --defaults core.disable_connection_verification=true
```

#### Corporate Firewall

Ensure these URLs are whitelisted:
- `https://management.azure.com/` - Azure Resource Manager
- `https://login.microsoftonline.com/` - Authentication
- `https://graph.microsoft.com/` - Microsoft Graph

### Command-Specific Issues

#### APIM Commands Failing

```bash
# Check if APIM extension is installed
az extension list --query "[?name=='apim']"

# Install APIM extension if missing
az extension add --name apim

# Update extension to latest version
az extension update --name apim
```

#### REST API Calls

```bash
# Debug REST calls
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-apim-demo/providers/Microsoft.ApiManagement/service/apim-demo/apis?api-version=2021-08-01" \
  --verbose

# Check API version support
az provider show --namespace Microsoft.ApiManagement --query "resourceTypes[?resourceType=='service'].apiVersions" --output table
```

## Environment-Specific Configuration

### Development Environment

```bash
# Set development defaults
az configure --defaults \
  group=rg-apim-dev \
  location=eastus \
  output=table

# Use interactive login
az login
```

### CI/CD Environment

```bash
# Use service principal (set in environment variables)
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_TENANT_ID="your-tenant-id"

# Login non-interactively
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Set subscription
az account set --subscription "your-subscription-id"
```

### Local Development with Make

Add to your `.env` file:

```bash
# Azure Configuration
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id  # Optional for service principal
AZURE_CLIENT_SECRET=your-secret  # Optional for service principal

# Default Resource Configuration
RG=rg-apim-dev
LOCATION=eastus
```

## Verification Commands

Check your Azure CLI setup with these commands:

```bash
# Comprehensive check
make check-azure-auth

# Manual verification
az account show --query "{subscription:name, user:user.name, tenant:tenantId}" --output table
az group list --query "[].{Name:name, Location:location}" --output table
az provider show --namespace Microsoft.ApiManagement --query "registrationState" --output tsv
```

## Best Practices

### Security

1. **Use specific scopes** for service principals
2. **Rotate credentials** regularly
3. **Use managed identities** where possible
4. **Never commit credentials** to source control

### Performance

1. **Set defaults** to avoid repetitive parameters
2. **Use specific API versions** in scripts
3. **Cache authentication** in CI/CD pipelines
4. **Use batch operations** when possible

### Maintenance

1. **Update Azure CLI** regularly: `az upgrade`
2. **Update extensions**: `az extension update --name apim`
3. **Monitor deprecation notices** in command output
4. **Test authentication** before deployments