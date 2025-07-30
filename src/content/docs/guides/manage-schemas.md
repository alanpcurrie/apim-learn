---
title: "How to Manage Schemas in Azure API Management"
description: "This guide shows you how to upload, manage, and use JSON schemas in Azure API Management for request/response validation."
---


This guide shows you how to upload, manage, and use JSON schemas in Azure API Management for request/response validation.

## Prerequisites

- Completed [Deploy the Cars API](deploy-api.md)
- JSON schema files ready to upload
- `jq` installed for JSON processing

## What are Schemas in APIM?

Schemas in Azure API Management are reusable definitions that can be used to:
- Validate request and response payloads
- Generate API documentation
- Provide IntelliSense in the Azure Portal
- Enable automatic SDK generation

**Note:** Schemas in APIM are associated with specific APIs. Each API can have its own set of schemas.

## Schema Files Structure

Our project includes these schema files in the `schemas/` directory:

- `car-schema.json` - Defines the structure of a single car object
- `cars-list-schema.json` - Defines the structure of the cars array response

## Upload Schemas

### Upload All Schemas at Once

The easiest way to upload all schemas:

```bash
make upload-all-schemas
```

This command will:
1. Find all `.json` files in the `schemas/` directory
2. Upload each as a schema to APIM
3. Use the filename (without extension) as the schema ID

**Example output:**
```
Uploading all schemas from schemas/ directory...
Uploading schema: car-schema
Schema 'car-schema' created/updated successfully!
Uploading schema: cars-list-schema
Schema 'cars-list-schema' created/updated successfully!
All schemas uploaded successfully!
```

### Upload Individual Schema

To upload a specific schema:

```bash
make create-schema SCHEMA_ID=car-schema SCHEMA_FILE=schemas/car-schema.json
```

Parameters:
- `SCHEMA_ID`: Unique identifier for the schema in APIM
- `SCHEMA_FILE`: Path to the JSON schema file

**Azure CLI equivalent:**
```bash
az apim api schema create \
  --resource-group $RG \
  --service-name $APIM \
  --api-id $API_ID \
  --schema-id car-schema \
  --schema-type "application/json" \
  --schema-path schemas/car-schema.json
```

## List Schemas

View all schemas in your APIM instance:

```bash
make list-schemas
```

**Azure CLI equivalent:**
```bash
az apim api schema list \
  --resource-group $RG \
  --service-name $APIM \
  --api-id $API_ID \
  --output table
```

**Example output:**
```
ContentType                                  Name                      ResourceGroup
-------------------------------------------  ------------------------  ---------------
application/vnd.oai.openapi.components+json  688612244634611b18783f62  apim-tester
application/json                             car-schema                apim-tester
application/json                             cars-list-schema          apim-tester
```

## View Schema Content

To view a specific schema's content:

```bash
make get-schema SCHEMA_ID=car-schema
```

**Azure CLI equivalent:**
```bash
az apim api schema show \
  --resource-group $RG \
  --service-name $APIM \
  --api-id $API_ID \
  --schema-id car-schema
```

**Example output:**
```json
{
  "contentType": "application/json",
  "id": "/subscriptions/.../schemas/car-schema",
  "name": "car-schema",
  "type": "Microsoft.ApiManagement/service/apis/schemas",
  "value": "{\n  \"$schema\": \"http://json-schema.org/draft-07/schema#\",\n  \"title\": \"Car\",\n  ...}"
}
```

## Update a Schema

To update an existing schema, use the same create command:

```bash
make create-schema SCHEMA_ID=car-schema SCHEMA_FILE=schemas/car-schema-updated.json
```

The schema will be replaced with the new content.

## Delete a Schema

To remove a schema from APIM:

```bash
make delete-schema SCHEMA_ID=car-schema
```

**Warning:** Deleting a schema that's referenced in policies will cause validation errors.

## Use Schemas in Policies

Once uploaded, you can reference schemas in validation policies:

### Request Validation Policy

```xml
<validate-content unspecified-content-type-action="prevent" max-size="102400" size-exceeded-action="prevent">
    <content type="application/json" validate-as="json" schema-id="car-schema" />
</validate-content>
```

### Response Validation Policy

```xml
<outbound>
    <validate-content unspecified-content-type-action="prevent" max-size="102400" size-exceeded-action="prevent">
        <content type="application/json" validate-as="json" schema-id="cars-list-schema" />
    </validate-content>
</outbound>
```

## Schema Best Practices

1. **Use Descriptive IDs**: Schema IDs should clearly indicate what they validate
2. **Version Your Schemas**: Include version in schema ID (e.g., `car-v1-schema`)
3. **Add Descriptions**: Include helpful descriptions in your schema properties
4. **Set Constraints**: Use `minLength`, `maxLength`, `minimum`, `maximum` for validation
5. **Test Thoroughly**: Validate schemas work correctly before using in production

## Common Issues

### Schema Upload Fails

If schema upload fails with JSON parsing error:

1. Validate your JSON schema:
   ```bash
   jq . schemas/car-schema.json
   ```

2. Ensure the schema follows JSON Schema Draft-07 specification

### Schema Not Found in Policy

If a policy can't find a schema:

1. Verify the schema ID matches exactly (case-sensitive)
2. Check the schema was uploaded successfully:
   ```bash
   make list-schemas
   ```

### Validation Errors

If requests fail validation:

1. Check the exact error message in the response
2. Verify the request payload matches the schema structure
3. Test the schema validation locally first

## Complete End-to-End Testing Workflow

Here's what we tested in our schema management implementation:

### 1. Upload All Schemas

```bash
# Upload both car schemas at once
make upload-all-schemas
```

**Result:** Both `car-schema` and `cars-list-schema` were successfully uploaded.

### 2. Verify Schemas Were Uploaded

```bash
# List all schemas for the API
make list-schemas
```

**Output shows:**
- `car-schema` - for single car objects
- `cars-list-schema` - for arrays of cars
- OpenAPI components schema (auto-generated)

### 3. Apply Mock Policy with Valid Data

```bash
# Apply a policy that returns schema-compliant mock data
make apply-api-policy API_POLICY_FILE=policies/cars-api/mock-with-validation.xml
```

### 4. Test the Endpoints

```bash
# Test list cars endpoint
make test-list-cars

# Test get single car endpoint
make test-get-car
```

**Both endpoints returned:**
- HTTP 200 status
- JSON data that matches our schemas
- All required fields present
- Correct data types (integers for id/year, strings for others)

## Example: Complete Schema Workflow

Here's a complete example of adding schema validation to an API:

1. **Create a schema file** (`schemas/create-car-schema.json`):
   ```json
   {
     "$schema": "http://json-schema.org/draft-07/schema#",
     "type": "object",
     "properties": {
       "make": { "type": "string", "minLength": 1 },
       "model": { "type": "string", "minLength": 1 },
       "year": { "type": "integer", "minimum": 1900 }
     },
     "required": ["make", "model", "year"]
   }
   ```

2. **Upload the schema**:
   ```bash
   make create-schema SCHEMA_ID=create-car-schema SCHEMA_FILE=schemas/create-car-schema.json
   ```

3. **Create a validation policy** (`policies/cars-api/operations/create-car.xml`):
   ```xml
   <policies>
       <inbound>
           <validate-content unspecified-content-type-action="prevent" max-size="1024" size-exceeded-action="prevent">
               <content type="application/json" validate-as="json" schema-id="create-car-schema" />
           </validate-content>
       </inbound>
   </policies>
   ```

4. **Apply the policy**:
   ```bash
   make apply-operation-policy OPERATION_ID=createCar OPERATION_POLICY_FILE=policies/cars-api/operations/create-car.xml
   ```

## Next Steps

- [Configure Request Validation](configure-validation.md)
- [Test API Endpoints](test-endpoints.md)
- [Debug Policy Errors](debug-policies.md)

## Related References

- [JSON Schema Specification](https://json-schema.org/draft-07/json-schema-release-notes.html)
- [Azure APIM Schema Management](https://docs.microsoft.com/en-us/azure/api-management/api-management-howto-schemas)
- [Validation Policies](../reference/policy-reference.md#validation-policies)
