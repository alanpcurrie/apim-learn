---
title: API Design Philosophy
description: REST, HATEOAS, and discoverable APIs inspired by Stripe and the web's original vision
---

# API Design Philosophy

Great API design isn't just about endpoints and JSON—it's about creating systems that are discoverable, self-documenting, and follow the principles that made the web successful. This guide explores REST, HATEOAS, and discoverability through the lens of exemplary APIs like Stripe's.

## The Web's Original Vision

The web was designed around a simple but powerful concept: **hypermedia as the engine of application state** (HATEOAS). Every resource should tell you what you can do next through links, just like web pages do.

> "The Web's architecture is based on the concept that every resource should be identified by a URL, and that the representation of a resource should contain information about what can be done with that resource." — Roy Fielding, creator of REST

## REST: More Than Just HTTP Verbs

REST isn't just about using `GET`, `POST`, `PUT`, and `DELETE`. True REST embraces:

### 1. Resource-Oriented Design
```
# Good: Resources as nouns
GET /cars/123
POST /cars
PUT /cars/123

# Avoid: Actions as verbs  
POST /getCar/123
POST /updateCar/123
```

### 2. Stateless Communication
Each request contains all information needed to understand it. No server-side session state.

### 3. Uniform Interface
Consistent patterns across your entire API. If `/cars` works one way, `/drivers` should work similarly.

## HATEOAS: The Missing Link

Most APIs stop at resource representation, but HATEOAS adds **discoverability** through links.

### Stripe's Approach
Stripe's API is a masterclass in HATEOAS. Look at a payment object:

```json
{
  "id": "pi_1234567890",
  "object": "payment_intent",
  "amount": 2000,
  "currency": "usd",
  "status": "requires_confirmation",
  "client_secret": "pi_1234567890_secret_abcd",
  "links": {
    "confirm": {
      "href": "/v1/payment_intents/pi_1234567890/confirm",
      "method": "POST"
    },
    "cancel": {
      "href": "/v1/payment_intents/pi_1234567890/cancel", 
      "method": "POST"
    }
  }
}
```

The API tells you exactly what actions are available based on the current state.

### Implementing Links in Your API

```json
{
  "id": "car_123",
  "make": "Toyota",
  "model": "Supra",
  "status": "available",
  "_links": {
    "self": {
      "href": "/api/v1/cars/car_123"
    },
    "rent": {
      "href": "/api/v1/cars/car_123/rent",
      "method": "POST",
      "title": "Rent this car"
    },
    "reserve": {
      "href": "/api/v1/cars/car_123/reserve",
      "method": "POST",
      "title": "Reserve this car"
    },
    "specifications": {
      "href": "/api/v1/cars/car_123/specs",
      "method": "GET"
    }
  }
}
```

## Discoverability: APIs as Conversations

### Start with a Root Resource
Your API should have an entry point that reveals the entire API surface:

```json
GET /api/v1/

{
  "version": "1.0",
  "documentation": "https://docs.example.com/api",
  "_links": {
    "cars": {
      "href": "/api/v1/cars",
      "title": "Manage cars"
    },
    "drivers": {
      "href": "/api/v1/drivers", 
      "title": "Manage drivers"
    },
    "rentals": {
      "href": "/api/v1/rentals",
      "title": "Car rentals"
    }
  }
}
```

### Progressive Disclosure
Don't overwhelm with every possible action. Show what's relevant for the current state:

```json
// New rental
{
  "id": "rental_456",
  "status": "pending",
  "_links": {
    "cancel": { "href": "/api/v1/rentals/rental_456/cancel" },
    "confirm": { "href": "/api/v1/rentals/rental_456/confirm" }
  }
}

// Active rental  
{
  "id": "rental_456", 
  "status": "active",
  "_links": {
    "complete": { "href": "/api/v1/rentals/rental_456/complete" },
    "extend": { "href": "/api/v1/rentals/rental_456/extend" }
  }
}
```

## Error Handling: RFC 7807 Problem Details

Use standardized error formats that are both human and machine readable:

```json
{
  "type": "https://example.com/probs/out-of-credit",
  "title": "You do not have enough credit.",
  "detail": "Your current balance is 30, but that costs 50.",
  "instance": "/account/12345/msgs/abc",
  "balance": 30,
  "accounts": ["/account/12345", "/account/67890"]
}
```

## API Versioning: Fast & Furious Timeline

Our Fast & Furious Cars API versions follow the movie timeline, with each version inspired by the themes and characters of each film. We start with characters from the original Fast & Furious movie until exhausted, then move to subsequent films:

### Original Fast & Furious Characters (2001)
- **2024-06-22.dom** *(The Fast and the Furious)*: The original - fast, simple street racing API. Core CRUD operations, basic authentication.
- **2024-09-15.letty** *(Letty Ortiz)*: Partnership features - multi-car bookings, driver partnerships, shared resources.
- **2025-01-18.vince** *(Vince)*: Performance features - caching, optimization, high-speed operations.
- **2025-04-12.jesse** *(Jesse)*: Technical features - advanced filtering, complex queries, data analytics.

### 2 Fast 2 Furious Characters (2003)
- **2025-07-30.brian** *(Brian O'Conner)*: Law enforcement integration - enhanced security, compliance features, audit trails.
- **2025-10-25.roman** *(Roman Pearce)*: Bulk operations - batch processing, high-volume transactions.

### Future Versions
- **Latest**: Current development version with all the latest features

*"It don't matter if you win by an inch or a mile. Winning's winning." - Dom*

### Date-Based Versioning Benefits
This approach combines **Stripe's date-based versioning** with **thematic character names**:
- Clear chronological progression
- Memorable codenames that reflect version personality
- Easy deprecation timeline management
- Character traits hint at version features

```http
# API version header
Fast-Furious-Version: 2024-06-22.dom

# Or in URL path  
GET /api/2024-06-22.dom/cars/123
```

## Azure API Management Integration

Azure APIM enhances discoverable APIs through:

- **Developer Portal**: Auto-generated, interactive documentation
- **Policy Injection**: Add HATEOAS links via policies
- **Response Transformation**: Enrich responses with navigational links
- **Mock Responses**: Test discoverability patterns before backend implementation

### Adding Links via APIM Policy

```xml
<policies>
  <inbound>
    <!-- Validate request -->
  </inbound>
  <outbound>
    <choose>
      <when condition="@(context.Response.StatusCode == 200)">
        <set-body>@{
          var body = context.Response.Body.As<JObject>();
          body["_links"] = new JObject {
            ["self"] = new JObject {
              ["href"] = "/api/v1/cars/" + body["id"]
            }
          };
          return body.ToString();
        }</set-body>
      </when>
    </choose>
  </outbound>
</policies>
```

## The HTMX Connection

[HTMX](https://htmx.org/) brings these same principles to the frontend, proving that hypermedia-driven applications scale from APIs to user interfaces.

> "The web is built on hypermedia. APIs should be too." — HTMX Essays

Key HTMX principles that apply to API design:
- **Hypermedia controls**: Links and forms drive state transitions
- **Progressive enhancement**: Start simple, add complexity gradually  
- **Server-driven UI**: The server knows what's possible, not the client

## Best Practices Summary

### ✅ Do
- Use consistent URL patterns across resources
- Include `_links` or `links` in responses
- Provide a discoverable root endpoint
- Make state transitions explicit through links
- Use standard HTTP status codes correctly
- Document link relations and their meanings

### ❌ Don't
- Require clients to construct URLs
- Hide available actions from API consumers
- Break REST constraints for convenience
- Use POST for everything
- Return different data structures for the same resource type

## Further Reading

### Essential Resources
- [Roy Fielding's REST Dissertation](https://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm) - The original REST specification
- [Stripe API Documentation](https://stripe.com/docs/api) - Exemplary API design in practice
- [RFC 7807 - Problem Details](https://tools.ietf.org/html/rfc7807) - Standard error response format
- [HTMX Essays](https://htmx.org/essays/) - Hypermedia-driven application architecture

### Advanced Topics
- [JSON:API](https://jsonapi.org/) - Specification for building APIs with JSON
- [HAL (Hypertext Application Language)](http://stateless.co/hal_specification.html) - Simple format for expressing hyperlinks
- [OpenAPI 3.1 Links](https://swagger.io/specification/#link-object) - Describing relationships between operations

### Azure APIM Resources
- [Response Transformation Policies](https://docs.microsoft.com/azure/api-management/api-management-transformation-policies)
- [Developer Portal Customization](https://docs.microsoft.com/azure/api-management/api-management-customize-styles)
- [Mock Response Policies](https://docs.microsoft.com/azure/api-management/mock-api-responses)

---

*"The best APIs feel like conversations, not interrogations. Every response should tell you what you can do next, just like the web intended."*