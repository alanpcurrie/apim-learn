# Azure API Management Deployment Automation

# Include .env file if it exists
-include .env
export

# Variables for configuration (use .env values or defaults)
RESOURCE_GROUP ?= $(RG)
APIM_SERVICE_NAME ?= $(APIM)
# Rename to avoid recursive reference
AZURE_API_ID ?= $(API_ID)
API_VERSION ?= v1
API_VERSION_SET_ID ?= $(API_VERSION_SET_ID)
API_PATH ?= cars
OPENAPI_SPEC ?= openapi/cars-api.yaml
API_POLICY_FILE ?= policies/cars-api/global.xml
MOCK_POLICY_FILE ?= policies/cars-api/simple-mock.xml
APIM_GATEWAY_URL ?= $(shell az apim show --resource-group $(RESOURCE_GROUP) --name $(APIM_SERVICE_NAME) --query gatewayUrl -o tsv 2>/dev/null)

# Environment check target
.PHONY: env-check
env-check:
	@echo "🔍 Checking required env vars..."
	@if [ -z "$(RG)" ] || [ -z "$(APIM)" ] || [ -z "$(API_ID)" ]; then \
		echo "❌ Missing one or more required env vars: RG, APIM, API_ID"; \
		echo "💡 Create a .env file from .env.example:"; \
		echo "   cp .env.example .env"; \
		echo "   Then edit .env with your values"; \
		exit 1; \
	else \
		echo "✅ All required env vars set"; \
		echo "   RG=$(RG)"; \
		echo "   APIM=$(APIM)"; \
		echo "   API_ID=$(API_ID)"; \
	fi

# Default target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  env-check        - Check required environment variables"
	@echo "  install          - Install npm dependencies"
	@echo "  lint             - Lint OpenAPI specification with Spectral"
	@echo "  lint-quiet       - Lint OpenAPI spec (quiet mode, errors only)"
	@echo "  lint-strict      - Strict linting (fails on errors)"
	@echo "  lint-json        - Lint OpenAPI spec with JSON output"
	@echo "  validate-api     - Run all API validations"
	@echo ""
	@echo "Azure Resource Provisioning:"
	@echo "  check-azure-auth - Check Azure CLI authentication"
	@echo "  create-resource-group - Create Azure resource group"
	@echo "  create-apim      - Create Azure API Management instance"
	@echo "  provision-azure  - Full Azure provisioning (RG + APIM)"
	@echo "  check-provisioning - Check provisioning status"
	@echo ""
	@echo "Deployment:"
	@echo "  create-api       - Create/update API (with validation)"
	@echo "  create-api-force - Create/update API (skip validation)"
	@echo "  apply-api-policy - Apply policy at API level"
	@echo "  apply-mock-policy - Apply mock response policy"
	@echo "  apply-operation-policy OPERATION_ID=<id> - Apply policy at operation level"
	@echo "  deploy           - Full deployment (with validation)"
	@echo "  deploy-safe      - Full deployment with all checks"
	@echo "  deploy-mock      - Deploy with mock responses"
	@echo ""
	@echo "API Operations:"
	@echo "  list-operations  - List all operations in the API"
	@echo "  show-api         - Display API details"
	@echo "  export-api       - Export API definition"
	@echo "  clean            - Delete the API"
	@echo ""
	@echo "Testing:"
	@echo "  test-endpoints   - Test API endpoints"
	@echo "  test-list-cars   - Test the list cars endpoint"
	@echo "  test-get-car     - Test get car by ID endpoint"
	@echo ""
	@echo "Subscriptions:"
	@echo "  get-keys         - Get subscription keys"
	@echo "  list-subscriptions - List all API subscriptions"
	@echo "  create-subscription - Create API subscription"
	@echo "  add-to-product   - Add API to starter product"
	@echo ""
	@echo "Policies:"
	@echo "  delete-policy    - Delete API policy"
	@echo ""
	@echo "Schema Management:"
	@echo "  create-schema SCHEMA_ID=<id> SCHEMA_FILE=<path> - Create/update a schema"
	@echo "  list-schemas     - List all schemas in APIM"
	@echo "  get-schema SCHEMA_ID=<id> - Get a specific schema"
	@echo "  delete-schema SCHEMA_ID=<id> - Delete a schema"
	@echo "  upload-all-schemas - Upload all schemas from schemas/ directory"
	@echo ""
	@echo "Configuration:"
	@echo "  Create a .env file from .env.example for your environment variables"

# Create API version set
.PHONY: create-version-set
create-version-set: env-check
	@echo "Creating/Updating API version set '$(API_VERSION_SET_ID)'..."
	@az apim api versionset create \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--version-set-id $(API_VERSION_SET_ID) \
		--display-name "Cars API Version Set" \
		--description "Version set for Fast & Furious Cars API" \
		--versioning-scheme "Segment" \
		--version-query-name "api-version" \
		--version-header-name "Api-Version" 2>/dev/null || echo "Version set already exists or updated"

# Validate API before deployment
.PHONY: validate-api
validate-api: lint-strict validate-spec
	@echo "✅ All validations passed!"

# Create or update the API from OpenAPI specification (with validation)
.PHONY: create-api
create-api: env-check create-version-set
	@if [ -z "$(SKIP_LINT)" ]; then \
		echo "🔍 Validating OpenAPI specification before deployment..."; \
		$(MAKE) lint-strict || { \
			echo ""; \
			echo "⚠️  To skip validation and force deployment, use: SKIP_LINT=true make create-api"; \
			exit 1; \
		}; \
	else \
		echo "⚠️  Skipping OpenAPI validation (SKIP_LINT=true)"; \
	fi
	@echo "Creating/Updating API '$(AZURE_API_ID)' from OpenAPI spec..."
	az apim api import \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--path $(API_PATH) \
		--specification-path $(OPENAPI_SPEC) \
		--specification-format OpenApi \
		--api-version $(API_VERSION) \
		--api-version-set-id $(API_VERSION_SET_ID) \
		--subscription-required true
	@echo "API created/updated successfully!"

# Create or update the API without validation (force)
.PHONY: create-api-force
create-api-force: env-check create-version-set
	@echo "⚠️  Creating/Updating API without validation..."
	@SKIP_LINT=true $(MAKE) create-api

# Apply policy at API level
.PHONY: apply-api-policy
apply-api-policy: env-check
	@echo "Applying API-level policy..."
	@echo "Using policy file: $(API_POLICY_FILE)"
	az rest --method PUT \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/apis/$(AZURE_API_ID)/policies/policy?api-version=2021-08-01" \
		--body @$(API_POLICY_FILE) \
		--headers "Content-Type=application/vnd.ms-azure-apim.policy.raw+xml" \
		--output none
	@echo "API policy applied successfully!"

# Apply policy at operation level
# Usage: make apply-operation-policy OPERATION_ID=get-users OPERATION_POLICY_FILE=policies/get-users-policy.xml
.PHONY: apply-operation-policy
apply-operation-policy: env-check
	@if [ -z "$(OPERATION_ID)" ]; then \
		echo "Error: OPERATION_ID is required. Usage: make apply-operation-policy OPERATION_ID=<id> OPERATION_POLICY_FILE=<path>"; \
		exit 1; \
	fi
	@if [ -z "$(OPERATION_POLICY_FILE)" ]; then \
		echo "Error: OPERATION_POLICY_FILE is required. Usage: make apply-operation-policy OPERATION_ID=<id> OPERATION_POLICY_FILE=<path>"; \
		exit 1; \
	fi
	@echo "Applying policy to operation '$(OPERATION_ID)'..."
	az apim api operation policy set \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--operation-id $(OPERATION_ID) \
		--xml-policy-path $(OPERATION_POLICY_FILE)
	@echo "Operation policy applied successfully!"

# List all operations in the API
.PHONY: list-operations
list-operations: env-check
	@echo "Listing operations for API '$(AZURE_API_ID)'..."
	az apim api operation list \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--output table

# Test API endpoints
.PHONY: test-endpoints
test-endpoints: env-check
	@echo "Testing API endpoints..."
	@echo "Gateway URL: $(APIM_GATEWAY_URL)"
	@echo "API Path: $(API_PATH)"
	@echo "\nTesting with subscription key..."
	# Example: Test GET endpoint
	curl -X GET "$(APIM_GATEWAY_URL)/$(API_PATH)/" \
		-H "Ocp-Apim-Subscription-Key: $(SUBSCRIPTION_KEY)" \
		-H "Accept: application/json" \
		-w "\nHTTP Status: %{http_code}\n"
	# Add more test cases as needed

# Test specific endpoint
# Usage: make test-endpoint ENDPOINT=users METHOD=GET
.PHONY: test-endpoint
test-endpoint:
	@if [ -z "$(ENDPOINT)" ]; then \
		echo "Error: ENDPOINT is required. Usage: make test-endpoint ENDPOINT=<path> METHOD=<http-method>"; \
		exit 1; \
	fi
	@if [ -z "$(METHOD)" ]; then \
		echo "Error: METHOD is required. Usage: make test-endpoint ENDPOINT=<path> METHOD=<http-method>"; \
		exit 1; \
	fi
	curl -X $(METHOD) "$(APIM_GATEWAY_URL)/$(API_PATH)/$(ENDPOINT)" \
		-H "Ocp-Apim-Subscription-Key: $(SUBSCRIPTION_KEY)" \
		-H "Accept: application/json" \
		-H "Content-Type: application/json" \
		-w "\nHTTP Status: %{http_code}\n"

# Show API details
.PHONY: show-api
show-api: env-check
	@echo "API Details for '$(AZURE_API_ID)':"
	az apim api show \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--output yaml

# Clean up - Delete the API
.PHONY: clean
clean: env-check
	@echo "WARNING: This will delete the API '$(AZURE_API_ID)' from APIM service '$(APIM_SERVICE_NAME)'"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	az apim api delete \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--yes
	@echo "API deleted successfully!"

# Full deployment: create API and apply policies
.PHONY: deploy
deploy: env-check create-api apply-api-policy
	@echo "Deployment completed successfully!"

# Safe deployment with all validations
.PHONY: deploy-safe
deploy-safe: validate-api deploy
	@echo "Safe deployment completed successfully!"

# Validate OpenAPI specification
.PHONY: validate-spec
validate-spec:
	@echo "Validating OpenAPI specification..."
	@if [ -f "$(OPENAPI_SPEC)" ]; then \
		echo "OpenAPI spec file '$(OPENAPI_SPEC)' found."; \
	else \
		echo "Error: OpenAPI spec file '$(OPENAPI_SPEC)' not found!"; \
		exit 1; \
	fi

# Install npm dependencies
.PHONY: install
install:
	@echo "Installing npm dependencies..."
	npm install

# Lint OpenAPI specification with Spectral
.PHONY: lint
lint: install
	@echo "Linting OpenAPI specification with Spectral..."
	npm run lint

# Lint quietly (only show errors)
.PHONY: lint-quiet
lint-quiet: install
	@echo "Linting OpenAPI specification (quiet mode)..."
	npm run lint:quiet

# Strict linting - fails on any errors
.PHONY: lint-strict
lint-strict: install
	@echo "🔍 Running strict OpenAPI validation..."
	@if npm run lint:quiet 2>&1 | grep -E "error|Error"; then \
		echo ""; \
		echo "❌ OpenAPI specification has errors that must be fixed before deployment!"; \
		echo "💡 Run 'make lint' to see all issues"; \
		exit 1; \
	else \
		echo "✅ OpenAPI specification passed validation"; \
	fi

# Lint and output as JSON
.PHONY: lint-json
lint-json: install
	@echo "Linting OpenAPI specification (JSON output)..."
	npm run lint:json

# Lint for RFC 9457 compliance
.PHONY: lint-rfc9457
lint-rfc9457: install
	@echo "Checking RFC 9457 compliance..."
	npm run lint:rfc9457

# Lint all OpenAPI files
.PHONY: lint-all
lint-all: install
	@echo "Linting all OpenAPI specifications..."
	npm run lint:all

# Export API definition
.PHONY: export-api
export-api: env-check
	@echo "Exporting API definition..."
	az apim api export \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--export-format OpenApi \
		--file-path exported-$(AZURE_API_ID).yaml
	@echo "API exported to exported-$(AZURE_API_ID).yaml"

# Apply mock response policy
.PHONY: apply-mock-policy
apply-mock-policy: env-check
	@echo "Applying mock response policy..."
	@echo "Using policy file: $(MOCK_POLICY_FILE)"
	az rest --method PUT \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/apis/$(AZURE_API_ID)/policies/policy?api-version=2021-08-01" \
		--body @$(MOCK_POLICY_FILE) \
		--headers "Content-Type=application/vnd.ms-azure-apim.policy.raw+xml" \
		--output none
	@echo "Mock policy applied successfully!"

# Delete API policy
.PHONY: delete-policy
delete-policy: env-check
	@echo "Deleting API policy..."
	az rest --method DELETE \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/apis/$(AZURE_API_ID)/policies/policy?api-version=2021-08-01"
	@echo "API policy deleted successfully!"

# Create or update a schema in APIM
# Usage: make create-schema SCHEMA_ID=car-schema SCHEMA_FILE=schemas/car-schema.json
.PHONY: create-schema
create-schema: env-check
	@if [ -z "$(SCHEMA_ID)" ]; then \
		echo "Error: SCHEMA_ID is required. Usage: make create-schema SCHEMA_ID=\u003cid\u003e SCHEMA_FILE=\u003cpath\u003e"; \
		exit 1; \
	fi
	@if [ -z "$(SCHEMA_FILE)" ]; then \
		echo "Error: SCHEMA_FILE is required. Usage: make create-schema SCHEMA_ID=\u003cid\u003e SCHEMA_FILE=\u003cpath\u003e"; \
		exit 1; \
	fi
	@echo "Creating/Updating schema '$(SCHEMA_ID)' in APIM..."
	az apim api schema create \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--schema-id $(SCHEMA_ID) \
		--schema-type "application/json" \
		--schema-path $(SCHEMA_FILE)
	@echo "Schema '$(SCHEMA_ID)' created/updated successfully!"

# List all schemas in APIM
.PHONY: list-schemas
list-schemas: env-check
	@echo "Listing all schemas for API '$(AZURE_API_ID)'..."
	az apim api schema list \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--output table

# Get a specific schema
# Usage: make get-schema SCHEMA_ID=car-schema
.PHONY: get-schema
get-schema: env-check
	@if [ -z "$(SCHEMA_ID)" ]; then \
		echo "Error: SCHEMA_ID is required. Usage: make get-schema SCHEMA_ID=<id>"; \
		exit 1; \
	fi
	@echo "Getting schema '$(SCHEMA_ID)'..."
	az apim api schema show \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--schema-id $(SCHEMA_ID)

# Delete a schema
# Usage: make delete-schema SCHEMA_ID=car-schema
.PHONY: delete-schema
delete-schema: env-check
	@if [ -z "$(SCHEMA_ID)" ]; then \
		echo "Error: SCHEMA_ID is required. Usage: make delete-schema SCHEMA_ID=<id>"; \
		exit 1; \
	fi
	@echo "WARNING: This will delete the schema '$(SCHEMA_ID)'"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	az apim api schema delete \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--api-id $(AZURE_API_ID) \
		--schema-id $(SCHEMA_ID) \
		--yes
	@echo "Schema '$(SCHEMA_ID)' deleted successfully!"

# Upload all schemas from the schemas directory
.PHONY: upload-all-schemas
upload-all-schemas: env-check
	@echo "Uploading all schemas from schemas/ directory..."
	@for schema_file in schemas/*.json; do \
		if [ -f "$$schema_file" ]; then \
			schema_id=$$(basename "$$schema_file" .json); \
			echo "Uploading schema: $$schema_id"; \
			$(MAKE) create-schema SCHEMA_ID="$$schema_id" SCHEMA_FILE="$$schema_file"; \
		fi; \
	done
	@echo "All schemas uploaded successfully!"

# List all subscriptions
.PHONY: list-subscriptions
list-subscriptions: env-check
	@echo "Listing all subscriptions for APIM service..."
	az rest --method GET \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions?api-version=2021-08-01" \
		--query "value[?properties.scope.contains(@,'$(AZURE_API_ID)')].{Name:name, State:properties.state, DisplayName:properties.displayName}" \
		--output table

# Get subscription keys
.PHONY: get-keys
get-keys: env-check
	@echo "Getting subscription keys..."
	@SUBSCRIPTION_ID=$$(az rest --method GET \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions?api-version=2021-08-01" \
		--query "value[0].name" -o tsv) && \
	if [ ! -z "$$SUBSCRIPTION_ID" ]; then \
		echo "Using subscription: $$SUBSCRIPTION_ID"; \
		az rest --method POST \
			--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions/$$SUBSCRIPTION_ID/listSecrets?api-version=2021-08-01" \
			--query "{PrimaryKey:primaryKey, SecondaryKey:secondaryKey}" \
			--output table; \
	else \
		echo "No subscriptions found"; \
	fi

# Test list cars endpoint
.PHONY: test-list-cars
test-list-cars: env-check
	@echo "Testing list cars endpoint..."
	@if [ -n "$(APIM_PRIMARY_KEY)" ]; then \
		KEY="$(APIM_PRIMARY_KEY)"; \
	else \
		KEY=$$(az rest --method GET \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions?api-version=2021-08-01" \
		--query "value[0].name" -o tsv | xargs -I {} az rest --method POST \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions/{}/listSecrets?api-version=2021-08-01" \
		--query "primaryKey" -o tsv); \
	fi && \
	echo "Using subscription key: $$KEY" && \
	curl -X GET "$(APIM_GATEWAY_URL)/$(API_PATH)/$(API_VERSION)/cars" \
		-H "Ocp-Apim-Subscription-Key: $$KEY" \
		-H "Accept: application/json" \
		-w "\nHTTP Status: %{http_code}\n"

# Test get car by ID endpoint
.PHONY: test-get-car
test-get-car: env-check
	@echo "Testing get car by ID endpoint (ID=1)..."
	@if [ -n "$(APIM_PRIMARY_KEY)" ]; then \
		KEY="$(APIM_PRIMARY_KEY)"; \
	else \
		KEY=$$(az rest --method GET \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions?api-version=2021-08-01" \
		--query "value[0].name" -o tsv | xargs -I {} az rest --method POST \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions/{}/listSecrets?api-version=2021-08-01" \
		--query "primaryKey" -o tsv); \
	fi && \
	echo "Using subscription key: $$KEY" && \
	curl -X GET "$(APIM_GATEWAY_URL)/$(API_PATH)/$(API_VERSION)/cars/1" \
		-H "Ocp-Apim-Subscription-Key: $$KEY" \
		-H "Accept: application/json" \
		-w "\nHTTP Status: %{http_code}\n"

# Deploy with mock responses
.PHONY: deploy-mock
deploy-mock: env-check create-api apply-mock-policy
	@echo "Deployment with mock responses completed successfully!"

# Add API to starter product
.PHONY: add-to-product
add-to-product: env-check
	@echo "Adding API to starter product..."
	az apim product api add \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_SERVICE_NAME) \
		--product-id starter \
		--api-id $(AZURE_API_ID)
	@echo "API added to starter product successfully!"

# Create a subscription for the API
.PHONY: create-subscription
create-subscription: env-check
	@echo "Creating subscription for Cars API..."
	az rest --method PUT \
		--uri "https://management.azure.com/subscriptions/$$(az account show --query id -o tsv)/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/subscriptions/cars-api-subscription?api-version=2021-08-01" \
		--body '{ "properties": { "scope": "/subscriptions/'$$(az account show --query id -o tsv)'/resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$(APIM_SERVICE_NAME)/apis/$(AZURE_API_ID)", "displayName": "Cars API Subscription" } }'
	@echo "Subscription created successfully!"

# =============================================================================
# Azure Resource Provisioning Targets
# =============================================================================

# Check Azure CLI authentication
.PHONY: check-azure-auth
check-azure-auth:
	@echo "🔍 Checking Azure CLI authentication..."
	@if ! az account show >/dev/null 2>&1; then \
		echo "❌ Not logged in to Azure CLI"; \
		echo "💡 Run 'az login' to authenticate"; \
		exit 1; \
	else \
		echo "✅ Azure CLI authenticated"; \
		echo "   Account: $$(az account show --query 'user.name' -o tsv)"; \
		echo "   Subscription: $$(az account show --query 'name' -o tsv)"; \
	fi

# Create Azure Resource Group
.PHONY: create-resource-group
create-resource-group: env-check check-azure-auth
	@echo "🏗️  Creating resource group '$(RESOURCE_GROUP)' in '$(LOCATION)'..."
	@if az group show --name $(RESOURCE_GROUP) >/dev/null 2>&1; then \
		echo "✅ Resource group '$(RESOURCE_GROUP)' already exists"; \
	else \
		az group create \
			--name $(RESOURCE_GROUP) \
			--location $(LOCATION); \
		echo "✅ Resource group '$(RESOURCE_GROUP)' created successfully!"; \
	fi

# Create Azure API Management instance
.PHONY: create-apim
create-apim: env-check check-azure-auth create-resource-group
	@echo "🚀 Creating APIM instance '$(APIM_SERVICE_NAME)' (this takes 15-45 minutes)..."
	@if az apim show --name $(APIM_SERVICE_NAME) --resource-group $(RESOURCE_GROUP) >/dev/null 2>&1; then \
		echo "✅ APIM instance '$(APIM_SERVICE_NAME)' already exists"; \
		az apim show --name $(APIM_SERVICE_NAME) --resource-group $(RESOURCE_GROUP) --query "{name:name,location:location,sku:sku.name,state:provisioningState}" -o table; \
	else \
		if [ -z "$(PUBLISHER_EMAIL)" ] || [ -z "$(PUBLISHER_NAME)" ]; then \
			echo "❌ PUBLISHER_EMAIL and PUBLISHER_NAME must be set in .env"; \
			echo "💡 Update your .env file with valid publisher information"; \
			exit 1; \
		fi; \
		echo "⏳ Starting APIM creation (Consumption tier)..."; \
		az apim create \
			--name $(APIM_SERVICE_NAME) \
			--resource-group $(RESOURCE_GROUP) \
			--location $(LOCATION) \
			--publisher-email "$(PUBLISHER_EMAIL)" \
			--publisher-name "$(PUBLISHER_NAME)" \
			--sku-name Consumption \
			--no-wait; \
		echo "✅ APIM creation started! Use 'make check-provisioning' to monitor progress"; \
		echo "📝 This will take 15-45 minutes to complete"; \
	fi

# Check provisioning status
.PHONY: check-provisioning
check-provisioning: env-check check-azure-auth
	@echo "🔍 Checking provisioning status..."
	@if az apim show --name $(APIM_SERVICE_NAME) --resource-group $(RESOURCE_GROUP) >/dev/null 2>&1; then \
		az apim show --name $(APIM_SERVICE_NAME) --resource-group $(RESOURCE_GROUP) --query "{name:name,location:location,sku:sku.name,state:provisioningState,gatewayUrl:gatewayUrl}" -o table; \
		STATE=$$(az apim show --name $(APIM_SERVICE_NAME) --resource-group $(RESOURCE_GROUP) --query "provisioningState" -o tsv); \
		if [ "$$STATE" = "Succeeded" ]; then \
			echo "✅ APIM instance is ready!"; \
			echo "🌐 Gateway URL: $$(az apim show --name $(APIM_SERVICE_NAME) --resource-group $(RESOURCE_GROUP) --query "gatewayUrl" -o tsv)"; \
		elif [ "$$STATE" = "Creating" ]; then \
			echo "⏳ APIM instance is still being created..."; \
		else \
			echo "⚠️  APIM instance state: $$STATE"; \
		fi; \
	else \
		echo "❌ APIM instance '$(APIM_SERVICE_NAME)' not found"; \
		echo "💡 Run 'make create-apim' to create it"; \
	fi

# Full Azure provisioning
.PHONY: provision-azure
provision-azure: env-check check-azure-auth
	@echo "🎯 Starting full Azure resource provisioning..."
	@echo "📋 This will create:"
	@echo "   • Resource Group: $(RESOURCE_GROUP)"
	@echo "   • APIM Instance: $(APIM_SERVICE_NAME) (Consumption tier)"
	@echo "   • Location: $(LOCATION)"
	@echo ""
	@echo "⏳ Estimated time: 15-45 minutes"
	@echo ""
	@read -p "Continue? [y/N]: " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "❌ Aborted by user"; \
		exit 1; \
	fi
	@$(MAKE) create-resource-group
	@$(MAKE) create-apim
	@echo ""
	@echo "🎉 Azure provisioning initiated!"
	@echo "💡 Monitor progress with 'make check-provisioning'"
	@echo "📝 Once complete, run 'make get-keys' to retrieve subscription keys"

# Cleanup - Delete Azure resources
.PHONY: cleanup-azure
cleanup-azure: env-check check-azure-auth
	@echo "⚠️  WARNING: This will DELETE all Azure resources!"
	@echo "📋 Resources to be deleted:"
	@echo "   • Resource Group: $(RESOURCE_GROUP)"
	@echo "   • APIM Instance: $(APIM_SERVICE_NAME)"
	@echo "   • ALL resources within the resource group"
	@echo ""
	@read -p "Are you sure? Type 'DELETE' to confirm: " confirm; \
	if [ "$$confirm" != "DELETE" ]; then \
		echo "❌ Aborted - resource group not deleted"; \
		exit 1; \
	fi
	@echo "🗑️  Deleting resource group '$(RESOURCE_GROUP)'..."
	@az group delete --name $(RESOURCE_GROUP) --yes --no-wait
	@echo "✅ Resource group deletion initiated (runs in background)"
