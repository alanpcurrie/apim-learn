---
title: "RFC 9457 Problem Details Implementation Guide"
description: "This document describes how we implement RFC 9457 (Problem Details for HTTP APIs) in our Fast & Furious Cars API."
---


This document describes how we implement [RFC 9457 (Problem Details for HTTP APIs)](https://datatracker.ietf.org/doc/html/rfc9457) in our Fast & Furious Cars API.

## Overview

RFC 9457 defines a standard format for error responses in HTTP APIs, replacing the older RFC 7807. It provides a consistent way to communicate error details to API consumers using the `application/problem+json` media type.

## Core Components

### 1. Base Problem Details Schema

The base `ProblemDetails` schema includes these required fields:

- **type** (string, URI): Identifies the problem type
- **title** (string): Human-readable summary
- **status** (number): HTTP status code

Optional fields:
- **detail** (string): Human-readable explanation specific to this occurrence
- **instance** (string, URI): Identifies the specific occurrence

### 2. Extended Problem Types

We've created specialized problem types for common scenarios:

#### OutOfCreditProblem
```json
{
  "type": "https://example.com/probs/out-of-credit",
  "title": "You do not have enough credit.",
  "status": 403,
  "detail": "Your current balance is 30, but that costs 50.",
  "instance": "/account/12345/msgs/abc",
  "balance": 30,
  "accounts": ["/account/12345", "/account/67890"]
}
```

#### ValidationProblemDetails
```json
{
  "type": "https://example.net/validation-error",
  "title": "Your request is not valid.",
  "status": 422,
  "errors": [
    {
      "detail": "must be a positive integer",
      "pointer": "#/age"
    }
  ]
}
```

#### RateLimitProblem
```json
{
  "type": "https://example.com/probs/rate-limit-exceeded",
  "title": "Rate limit exceeded",
  "status": 429,
  "detail": "You have exceeded the rate limit for this resource.",
  "retryAfter": 60,
  "limit": 100,
  "remaining": 0
}
```

## Implementation in OpenAPI

### 1. Component Files

- `openapi/components/problem-details.yaml` - Contains all RFC 9457 schemas and responses
- `openapi/cars-api.yaml` - References problem details for error responses

### 2. Error Response Mapping

| HTTP Status | Problem Type | Use Case |
|-------------|--------------|----------|
| 400 | ValidationProblemDetails | Invalid request data |
| 401 | ProblemDetails | Authentication failure |
| 403 | OutOfCreditProblem | Insufficient permissions/credit |
| 404 | CarNotFoundProblem | Resource not found |
| 429 | RateLimitProblem | Rate limit exceeded |
| 500 | ProblemDetails | Server errors |

## Azure API Management Integration

### Policy Updates Required

Update the global and operation policies to return RFC 9457 compliant responses:

```xml
<on-error>
    <choose>
        <when condition="@(context.Response.StatusCode == 404)">
            <return-response>
                <set-status code="404" reason="Not Found" />
                <set-header name="Content-Type" exists-action="override">
                    <value>application/problem+json</value>
                </set-header>
                <set-body>@{
                    var carId = context.Request.MatchedParameters["carId"];
                    return new JObject(
                        new JProperty("type", "https://example.com/probs/car-not-found"),
                        new JProperty("title", "Car not found"),
                        new JProperty("status", 404),
                        new JProperty("detail", $"Car with ID '{carId}' was not found."),
                        new JProperty("instance", context.Request.Url.Path),
                        new JProperty("carId", carId),
                        new JProperty("suggestion", "Please verify the car ID and try again.")
                    ).ToString();
                }</set-body>
            </return-response>
        </when>
    </choose>
</on-error>
```

## Linting and Validation

### Custom Spectral Rules

We've created `.spectral-rfc9457.yaml` with rules to ensure:

1. **Media Type Compliance**: All error responses use `application/problem+json`
2. **Required Fields**: type, title, and status are always present
3. **URI Format**: Problem type URIs are absolute
4. **Status Code Matching**: The status field matches the HTTP response code
5. **Extension Naming**: Custom fields use camelCase
6. **Documentation**: Problem types have meaningful descriptions

### Running RFC 9457 Compliance Checks

```bash
# Check RFC 9457 compliance
make lint-rfc9457

# Or with npm
npm run lint:rfc9457
```

## Client Implementation Examples

### JavaScript/TypeScript

```typescript
interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  [key: string]: any; // Extension members
}

async function handleApiError(response: Response) {
  if (response.headers.get('Content-Type')?.includes('application/problem+json')) {
    const problem: ProblemDetails = await response.json();
    
    switch (problem.type) {
      case 'https://example.com/probs/rate-limit-exceeded':
        const retryAfter = problem.retryAfter || 60;
        console.log(`Rate limited. Retry after ${retryAfter} seconds`);
        break;
        
      case 'https://example.com/probs/validation-error':
        console.log('Validation errors:', problem.errors);
        break;
        
      default:
        console.log(`Error: ${problem.title} - ${problem.detail}`);
    }
  }
}
```

### Python

```python
import requests
from typing import Dict, Any

def handle_api_error(response: requests.Response) -> None:
    if 'application/problem+json' in response.headers.get('Content-Type', ''):
        problem: Dict[str, Any] = response.json()
        
        if problem['type'] == 'https://example.com/probs/rate-limit-exceeded':
            retry_after = problem.get('retryAfter', 60)
            print(f"Rate limited. Retry after {retry_after} seconds")
            
        elif problem['type'] == 'https://example.com/probs/validation-error':
            for error in problem.get('errors', []):
                print(f"Validation error at {error['pointer']}: {error['detail']}")
        
        else:
            print(f"Error: {problem['title']} - {problem.get('detail', '')}")
```

## Benefits

1. **Standardization**: Follows IETF standard for error responses
2. **Machine Readable**: Structured format allows automated error handling
3. **Human Readable**: Includes descriptions for debugging
4. **Extensible**: Can add custom fields while maintaining compatibility
5. **Content Negotiation**: Supports multiple formats (JSON, XML)

## Migration from Current Error Format

To migrate existing error responses:

1. Update all error responses to use `application/problem+json` media type
2. Map existing error codes to problem types
3. Update client libraries to handle new format
4. Provide transition period with both formats

## References

- [RFC 9457 Specification](https://datatracker.ietf.org/doc/html/rfc9457)
- [Problem Details Registry](https://www.iana.org/assignments/http-problem-types/http-problem-types.xhtml)
- [JSON Schema for Problem Details](https://json-schema.org/draft/2020-12/schema)
