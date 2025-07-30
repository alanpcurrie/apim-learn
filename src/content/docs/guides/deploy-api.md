---
title: "How to Deploy the Cars API"
description: "This guide shows you how to deploy the Fast & Furious Cars API to Azure API Management."
---


This guide shows you how to deploy the Fast & Furious Cars API to Azure API Management.

## Prerequisites

- Completed [Getting Started Tutorial](../tutorials/01-getting-started.md)
- Azure subscription with API Management instance
- Environment variables configured in `.env`
- Azure CLI logged in (`az login`)

## Quick Deployment

### Deploy with Validation (Recommended)

```bash
make deploy
```

This will:
1. Validate your OpenAPI specification using Spectral
2. Create/update the API in APIM
3. Apply the configured policies

### Deploy with All Safety Checks

```bash
make deploy-safe
```

Runs comprehensive validation before deployment.

### Deploy with Mock Responses

```bash
make deploy-mock
```

This deploys the API with built-in mock responses - no backend needed!

### Force Deployment (Skip Validation)

If you need to deploy without validation:

```bash
# Option 1: Use environment variable
SKIP_LINT=true make deploy

# Option 2: Use force command
make create-api-force
```

⚠️ **Warning**: Only skip validation if you're certain your OpenAPI spec is correct.

## Step-by-Step Deployment

### 1. Check Environment

```bash
make env-check
```

Expected output:

```bash
✅ All required env vars set
   RG=apim-tester      # Your actual resource group
   APIM=apim-tester    # Your actual APIM instance
   API_ID=cars-api
```

**Note:** Make sure your `.env` file has your actual Azure resource names, not the example values.

### 2. Validate OpenAPI Specification

#### Run Full Validation

```bash
make lint
```

This shows all warnings and errors in your OpenAPI spec.

#### Run Strict Validation (Errors Only)

```bash
make lint-strict
```

This fails if any errors are found. Used automatically during deployment.

#### Validate Everything

```bash
make validate-api
```

Runs all validation checks including:
- OpenAPI specification linting
- File existence checks
- Schema validation (if applicable)

Fix any errors before proceeding.

### 3. Create or Update the API

```bash
make create-api
```

This imports `openapi/cars-api.yaml` into your APIM instance.

### 4. Apply Global Policies

```bash
make apply-api-policy
```

This applies rate limiting, CORS, and security policies from `policies/cars-api/global.xml`.

### 5. Apply Operation-Specific Policies

```bash
make list-operations
```

Note the operation IDs, then apply operation policies:

```bash
make apply-operation-policy OPERATION_ID=getCarById OPERATION_POLICY_FILE=policies/cars-api/operations/get-car.xml
```

## Verify Deployment

### 1. Check API Status

```bash
make show-api
```

Look for:

- `state: published`
- `subscriptionRequired: true`
- Correct `path` value

### 2. Get Subscription Key

If you haven't already added subscription keys to your `.env` file:

```bash
make get-keys
```

This will display your subscription keys. Add them to your `.env` file:

```bash
APIM_PRIMARY_KEY=<displayed-primary-key>
APIM_SECONDARY_KEY=<displayed-secondary-key>
```

The test commands will automatically use these keys from your environment.

### 3. Test the API

#### Easy Way: Use the Test Commands

List all cars:

```bash
make test-list-cars
```

Get specific car:

```bash
make test-get-car
```

#### Manual Way: Using cURL

First get your gateway URL and subscription key:

```bash
# Get gateway URL
az apim show --resource-group apim-tester --name apim-tester --query gatewayUrl -o tsv
# Example output: https://apim-tester.azure-api.net

# Get master subscription key (works for all APIs)
az rest --method POST \
  --uri "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/apim-tester/providers/Microsoft.ApiManagement/service/apim-tester/subscriptions/master/listSecrets?api-version=2021-08-01" \
  --query primaryKey -o tsv
```

Then test:

```bash
# List all cars
curl -X GET "https://apim-tester.azure-api.net/cars/v1/cars" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY_HERE" \
  -H "Accept: application/json"

# Get specific car
curl -X GET "https://apim-tester.azure-api.net/cars/v1/cars/1" \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY_HERE" \
  -H "Accept: application/json"
```

## Update Existing Deployment

To update an already deployed API:

```bash
# Update API definition
make create-api

# Reapply policies if changed
make apply-api-policy
```

## Deployment Options

### Deploy Without Policies

```bash
make create-api
```

### Deploy to Different Environment

```bash
# Edit .env with new values
vim .env

# Verify new environment
make env-check

# Deploy
make deploy
```

### Deploy Specific Version

```bash
API_VERSION=v2 make create-api
```

## Common Issues

### "API already exists" Error

The API is already deployed. Use `make create-api` to update it.

### "Resource group not found" Error

Create the resource group first:

```bash
az group create --name $RG --location eastus
```

### "APIM service not found" Error

The APIM instance doesn't exist. See [Creating APIM Instance](create-apim-instance.md).

### Policy Application Fails

1. Check XML syntax:

   ```bash
   xmllint --noout policies/cars-api/global.xml
   ```

2. Verify operation ID:

   ```bash
   make list-operations
   ```

## Rollback

To remove the deployment:

```bash
make clean
```

**Warning:** This deletes the entire API configuration.

## Next Steps

Now that your API is deployed, continue your learning journey:

1. **🧪 [Test API Endpoints](/how-to/test-endpoints)** - Verify your deployment works correctly
2. **📊 [Understanding Policies](/tutorials/03-understanding-policies)** - Learn policy configuration with hands-on examples
3. **🔐 [Configure JWT Authentication](/how-to/configure-jwt-authentication)** - Add secure authentication
4. **🐛 [Debug Policy Issues](/how-to/debug-policy-issues)** - Master troubleshooting techniques

## Related References

- [Makefile Commands](../reference/makefile-commands.md)
- [Policy Reference](../reference/policy-reference.md)
- [Environment Variables](../reference/environment-variables.md)
