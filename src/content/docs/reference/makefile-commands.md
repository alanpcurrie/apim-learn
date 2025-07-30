---
title: "Makefile Commands Reference"
description: "Complete reference of all available `make` commands in this project."
---


Complete reference of all available `make` commands in this project.

## Command Overview

| Command | Purpose | Prerequisites |
|---------|---------|---------------|
| `make help` | Show all available commands | None |
| `make env-check` | Verify environment variables | .env file |
| `make install` | Install npm dependencies | Node.js |
| `make lint` | Lint OpenAPI specification | npm install |
| **Azure Resource Provisioning** |  |  |
| `make check-azure-auth` | Check Azure CLI authentication | Azure CLI |
| `make create-resource-group` | Create Azure resource group | Azure CLI auth |
| `make create-apim` | Create APIM instance | Resource group |
| `make provision-azure` | Full Azure provisioning | Azure CLI auth |
| `make check-provisioning` | Check provisioning status | Azure CLI auth |
| `make cleanup-azure` | Delete Azure resources | Azure CLI auth |
| **API Deployment** |  |  |
| `make create-api` | Create/update API in APIM | Azure resources |
| `make deploy` | Full deployment | Azure resources |
| `make deploy-mock` | Deploy with mock responses | Azure resources |
| `make clean` | Delete API from APIM | Azure resources |
| **Testing** |  |  |
| `make test-list-cars` | Test list cars endpoint | Deployed API |
| `make test-get-car` | Test get car endpoint | Deployed API |
| `make apply-mock-policy` | Apply mock response policy | Deployed API |
| `make delete-policy` | Delete API policy | Deployed API |
| **Subscriptions** |  |  |
| `make get-keys` | Get subscription keys | APIM instance |
| `make list-subscriptions` | List API subscriptions | APIM instance |
| `make add-to-product` | Add API to starter product | Deployed API |
| `make create-subscription` | Create API subscription | APIM instance |
| **Schema Management** |  |  |
| `make create-schema` | Upload/update a schema | APIM instance |
| `make list-schemas` | List all schemas | APIM instance |
| `make get-schema` | View schema content | APIM instance |
| `make delete-schema` | Delete a schema | APIM instance |
| `make upload-all-schemas` | Upload all schemas | APIM instance |

## Azure Resource Provisioning Commands

### `make check-azure-auth`

Verifies Azure CLI authentication and displays current account info.

**Usage:**

```bash
make check-azure-auth
```

**Output (Success):**

```bash
🔍 Checking Azure CLI authentication...
✅ Azure CLI authenticated
   Account: user@example.com
   Subscription: Pay-As-You-Go
```

**Output (Not authenticated):**

```bash
❌ Not logged in to Azure CLI
💡 Run 'az login' to authenticate
```

### `make create-resource-group`

Creates an Azure resource group if it doesn't exist.

**Usage:**

```bash
make create-resource-group
```

**Prerequisites:**
- Azure CLI authentication
- `RG` and `LOCATION` environment variables

**Output:**

```bash
🏗️ Creating resource group 'rg-apim-demo' in 'eastus'...
✅ Resource group 'rg-apim-demo' created successfully!
```

### `make create-apim`

Creates an Azure API Management instance (Consumption tier).

**Usage:**

```bash
make create-apim
```

**Prerequisites:**
- Resource group exists
- `PUBLISHER_EMAIL` and `PUBLISHER_NAME` environment variables

**Time:** 15-45 minutes

**Output:**

```bash
🚀 Creating APIM instance 'apim-demo' (this takes 15-45 minutes)...
⏳ Starting APIM creation (Consumption tier)...
✅ APIM creation started! Use 'make check-provisioning' to monitor progress
```

### `make provision-azure`

Full Azure resource provisioning with user confirmation.

**Usage:**

```bash
make provision-azure
```

**Interactive prompts:**

```bash
🎯 Starting full Azure resource provisioning...
📋 This will create:
   • Resource Group: rg-apim-demo
   • APIM Instance: apim-demo (Consumption tier)
   • Location: eastus

⏳ Estimated time: 15-45 minutes

Continue? [y/N]: y
```

### `make check-provisioning`

Monitors APIM provisioning status.

**Usage:**

```bash
make check-provisioning
```

**Output (In Progress):**

```bash
🔍 Checking provisioning status...
Name       Location  Sku         State      GatewayUrl
---------  --------  ----------  ---------  ----------
apim-demo  eastus    Consumption Creating   
⏳ APIM instance is still being created...
```

**Output (Complete):**

```bash
Name       Location  Sku         State      GatewayUrl
---------  --------  ----------  ---------  ---------------------------
apim-demo  eastus    Consumption Succeeded  https://apim-demo.azure-api.net
✅ APIM instance is ready!
🌐 Gateway URL: https://apim-demo.azure-api.net
```

### `make cleanup-azure`

Safely deletes all Azure resources.

**Usage:**

```bash
make cleanup-azure
```

**Safety confirmation:**

```bash
⚠️ WARNING: This will DELETE all Azure resources!
📋 Resources to be deleted:
   • Resource Group: rg-apim-demo
   • APIM Instance: apim-demo
   • ALL resources within the resource group

Are you sure? Type 'DELETE' to confirm: DELETE
```

## Environment Commands

### `make env-check`

Verifies all required environment variables are set.

**Usage:**

```bash
make env-check
```

**Output:**

```bash
🔍 Checking required env vars...
✅ All required env vars set
   RG=rg-apim-fast
   APIM=apim-fast-demo
   API_ID=cars-api
```

**Required Variables:**

- `RG` - Resource group name
- `APIM` - API Management service name
- `API_ID` - API identifier

## Setup Commands

### `make install`

Installs all npm dependencies (Spectral for OpenAPI linting).

**Usage:**

```bash
make install
```

**Prerequisites:**

- Node.js and npm installed

## Validation and Linting Commands

### `make lint`

Runs Spectral linter on OpenAPI specification with custom rules.

**Usage:**

```bash
make lint
```

**Output:** Shows all errors and warnings in stylish format.

### `make lint-strict`

Strict linting that fails on any errors. Used automatically during deployment.

**Usage:**

```bash
make lint-strict
```

**Output:**
- ✅ Success: "OpenAPI specification passed validation"
- ❌ Failure: Lists errors and suggests running `make lint`

### `make validate-api`

Runs all API validations before deployment.

**Usage:**

```bash
make validate-api
```

**Includes:**
- Strict OpenAPI linting
- Specification file existence check
- Future: Schema validation, policy validation

### Other Linting Commands

- `make lint-quiet` - Show only errors
- `make lint-json` - Output in JSON format
- `make lint-all` - Lint all OpenAPI files
- `make lint-rfc9457` - Check RFC 9457 compliance

### `make validate-spec`

Validates that OpenAPI specification file exists.

**Usage:**

```bash
make validate-spec
```

## Deployment Commands

### `make create-api`

Imports or updates the API from OpenAPI specification.

**Usage:**

```bash
make create-api
```

**Azure CLI equivalent:**

```bash
az apim api import \
  --resource-group $(RG) \
  --service-name $(APIM) \
  --api-id $(API_ID) \
  --path cars \
  --specification-path openapi/cars-api.yaml \
  --specification-format OpenApi \
  --api-version v1 \
  --subscription-required true
```

### `make apply-api-policy`

Applies global API-level policies.

**Usage:**

```bash
make apply-api-policy
```

**Policy file:** `policies/cars-api/global.xml`

### `make apply-operation-policy`

Applies policies to specific operations.

**Usage:**

```bash
make apply-operation-policy OPERATION_ID=getCarById OPERATION_POLICY_FILE=policies/cars-api/operations/get-car.xml
```

**Parameters:**

- `OPERATION_ID` - Operation identifier (required)
- `OPERATION_POLICY_FILE` - Path to policy XML file (required)

### `make deploy`

Performs full deployment (create API + apply policies).

**Usage:**

```bash
make deploy
```

**Equivalent to:**

```bash
make create-api
make apply-api-policy
```

### `make deploy-mock`

Deploys API with mock responses (no backend needed).

**Usage:**

```bash
make deploy-mock
```

**Equivalent to:**

```bash
make create-api
make apply-mock-policy
```

### `make apply-mock-policy`

Applies mock response policy for testing without a backend.

**Usage:**

```bash
make apply-mock-policy
```

**Policy file:** `policies/cars-api/simple-mock.xml`

## Information Commands

### `make list-operations`

Lists all operations in the API.

**Usage:**

```bash
make list-operations
```

**Output Example:**

```bash
Name                    Method    UrlTemplate
--------------------    ------    -----------
listCars               GET       /cars
getCarById             GET       /cars/{carId}
```

### `make show-api`

Displays detailed API information.

**Usage:**

```bash
make show-api
```

**Output:** YAML format with full API details

### `make show-keys`

Shows subscription keys for the APIM service.

**Usage:**

```bash
make show-keys
```

**Output:**

```bash
primaryKey       secondaryKey
-----------      -------------
<key-value>      <key-value>
```

### `make export-api`

Exports the current API definition from APIM.

**Usage:**

```bash
make export-api
```

**Output file:** `exported-cars-api.yaml`

## Testing Commands

### `make test-endpoints`

Tests API endpoints with subscription key.

**Usage:**

```bash
make test-endpoints
```

### `make test-endpoint`

Tests a specific endpoint.

**Usage:**

```bash
make test-endpoint ENDPOINT=cars/1 METHOD=GET
```

**Parameters:**

- `ENDPOINT` - API endpoint path (required)
- `METHOD` - HTTP method (required)

### `make test-list-cars`

Tests the list cars endpoint with automatic key retrieval.

**Usage:**

```bash
make test-list-cars
```

**Output Example:**

```json
[
  {
    "id": "1",
    "make": "Nissan",
    "model": "Skyline GT-R R34",
    "year": 1999,
    "color": "Bayside Blue",
    "driver": "Brian O'Conner",
    "movie": "2 Fast 2 Furious"
  },
  ...
]
```

### `make test-get-car`

Tests getting a specific car (ID=1) with automatic key retrieval.

**Usage:**

```bash
make test-get-car
```

## Cleanup Commands

### `make clean`

Deletes the API from APIM (with confirmation).

**Usage:**

```bash
make clean
```

**Warning:** This permanently deletes the API. You'll be prompted to confirm.

## Environment Variables

All commands use these environment variables:

| Variable | Description | Default | Source |
|----------|-------------|---------|---------|
| `RESOURCE_GROUP` | Azure resource group | `$(RG)` | .env |
| `APIM_SERVICE_NAME` | APIM instance name | `$(APIM)` | .env |
| `AZURE_API_ID` | API identifier | `$(API_ID)` | .env |
| `API_VERSION` | API version | `v1` | Makefile |
| `API_PATH` | API base path | `cars` | Makefile |
| `OPENAPI_SPEC` | OpenAPI file path | `openapi/cars-api.yaml` | Makefile |
| `API_POLICY_FILE` | Global policy path | `policies/cars-api/global.xml` | Makefile |

## Command Dependencies

```bash
env-check
    ├── create-api
    ├── apply-api-policy
    ├── apply-operation-policy
    ├── list-operations
    ├── test-endpoints
    ├── show-api
    ├── show-keys
    ├── export-api
    └── clean

install
    ├── lint
    ├── lint-quiet
    ├── lint-json
    ├── lint-rfc9457
    └── lint-all

deploy
    ├── env-check
    ├── create-api
    └── apply-api-policy
```

## Troubleshooting

### Command not found: make

- **macOS/Linux**: Usually pre-installed
- **Windows**: Install via Git Bash, WSL, or chocolatey

### Azure CLI errors

Ensure you're logged in:

```bash
az login
```

### Environment variable errors

Run `make env-check` to verify configuration.

## See Also

- [Environment Variables Reference](environment-variables.md)
- [How to Deploy the API](../how-to/deploy-api.md)
- [Troubleshooting Guide](../how-to/debug-policies.md)
