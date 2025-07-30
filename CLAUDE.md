# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Linting and Validation

- `npm run lint` - Lint the OpenAPI specification using Spectral
- `npm run lint:rfc9457` - Check RFC 9457 compliance specifically  
- `npm run validate` - Validate OpenAPI spec against OpenAPI standards
- `make lint` - Same as npm run lint (alternative via Makefile)

### Azure Deployment

- `make deploy` - Full deployment: create API + apply all policies
- `make create-api` - Deploy the OpenAPI spec to Azure APIM
- `make apply-api-policy` - Apply the global API policy
- `make apply-operation-policy OPERATION_ID=<id> OPERATION_POLICY_FILE=<path>` - Apply operation-specific policy

### Testing and Development

- `make test-endpoints` - Test API endpoints with subscription key
- `make show-api` - Display current API configuration in Azure
- `make show-keys` - Show subscription keys for testing

### Environment Setup

- Copy `.env.example` to `.env` and configure Azure details before deployment
- Required env vars: `RG` (resource group), `APIM` (service name), `API_ID`

## Architecture Overview

### OpenAPI Specification Structure

- **Main spec**: `openapi/cars-api.yaml` - Fast & Furious Cars API
- **Components**: `openapi/components/problem-details.yaml` - RFC 9457 error handling schemas
- **Error handling**: All error responses follow RFC 9457 standard using `application/problem+json`

### Azure APIM Policies

- **Global policy**: `policies/cars-api/global.xml` - Applied to entire API
  - Rate limiting (100 calls/minute)
  - CORS configuration  
  - JWT authentication (configurable)
  - Security response headers
  - RFC 9457 compliant error responses
- **Operation policies**: `policies/cars-api/operations/` - Operation-specific policies

### API Design Patterns

- Two main endpoints: `/cars` (list all) and `/cars/{carId}` (get specific)
- All error responses use RFC 9457 problem details format
- Comprehensive error schemas for different scenarios (validation, rate limits, etc.)
- Mock data includes Fast & Furious themed car information

### Configuration Files

- `.spectral.yaml` - Main OpenAPI linting rules with custom Cars API validations
- `.spectral-rfc9457.yaml` - Specific RFC 9457 compliance rules
- `Makefile` - Azure deployment automation and testing commands

### Key Integrations

- **Spectral CLI** for OpenAPI linting and validation
- **Azure CLI** for APIM deployment and management  
- **RFC 9457** standard for structured error responses
- **JWT authentication** via Azure AD (configurable in policies)

## Working with the Codebase

When modifying OpenAPI specs, always run linting before deployment:

```bash
npm run lint && npm run lint:rfc9457
```

When updating policies, use the Makefile commands to apply them systematically. The global policy handles most common scenarios, while operation-specific policies are in the `operations/` subdirectory.

The project follows a mock API pattern - all responses are examples in the OpenAPI spec rather than connecting to a real backend service.
