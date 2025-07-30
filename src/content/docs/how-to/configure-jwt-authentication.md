---
title: "Configure JWT Authentication"
description: "Learn how to set up JWT (JSON Web Token) authentication in Azure API Management with Azure AD integration and practical testing examples."
---

JWT (JSON Web Token) authentication provides secure, stateless authentication for your APIs. This guide shows you how to configure JWT validation in Azure API Management using Azure Active Directory.

## What You'll Learn

- Set up Azure AD application for JWT tokens
- Configure JWT validation policy in APIM  
- Test JWT authentication with real tokens
- Handle authentication errors properly
- Compare JWT vs subscription key authentication

## Prerequisites

- Completed [Understanding Policies](/tutorials/03-understanding-policies/)
- Azure AD tenant access
- Basic understanding of OAuth 2.0 and JWT

## Authentication Methods Comparison

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Subscription Keys** | Internal APIs, simple auth | Easy to implement | Less secure, no user context |
| **JWT Tokens** | User-facing APIs, mobile apps | Secure, user context, standards-based | More complex setup |
| **Client Certificates** | B2B APIs, high security | Very secure | Complex management |

## Step 1: Create Azure AD Application

First, create an Azure AD application to issue JWT tokens.

### Create the Application

```bash
# Login to Azure (if not already)
az login

# Create Azure AD application
az ad app create \
  --display-name "Cars API JWT Auth" \
  --identifier-uris "api://cars-api" \
  --sign-in-audience "AzureADMyOrg"
```

Save the returned `appId` - you'll need it for the policy configuration.

### Configure API Permissions

```bash
# Get the application ID from the previous command
APP_ID="your-app-id-here"

# Add delegated permissions for accessing the API
az ad app permission add \
  --id $APP_ID \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope
```

### Create Application Secret (for testing)

```bash
# Create client secret for testing
az ad app credential reset \
  --id $APP_ID \
  --display-name "Cars API Secret"
```

Save the returned `password` and `tenant` values.

## Step 2: Configure JWT Validation Policy

Now let's add JWT validation to our Cars API policy.

### Update Global Policy

Edit `policies/cars-api/global.xml` and add JWT validation in the inbound section:

```xml
<policies>
    <inbound>
        <base />
        
        <!-- JWT Validation -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
            <openid-config url="https://login.microsoftonline.com/{your-tenant-id}/v2.0/.well-known/openid-configuration" />
            <audiences>
                <audience>api://cars-api</audience>
            </audiences>
            <issuers>
                <issuer>https://login.microsoftonline.com/{your-tenant-id}/v2.0</issuer>
            </issuers>
        </validate-jwt>
        
        <!-- Fallback to subscription key if no Authorization header -->
        <choose>
            <when condition="@(!context.Request.Headers.ContainsKey("Authorization"))">
                <check-header name="Ocp-Apim-Subscription-Key" failed-check-httpcode="401" failed-check-error-message="Subscription key required" />
            </when>
        </choose>
        
        <!-- Rate limiting (existing) -->
        <rate-limit calls="100" renewal-period="60" />
        
        <!-- CORS (existing) -->
        <cors allow-credentials="false">
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
        </cors>
    </inbound>
    
    <backend>
        <base />
    </backend>
    
    <outbound>
        <base />
        <!-- Add user context to response headers -->
        <choose>
            <when condition="@(context.Request.Headers.ContainsKey("Authorization"))">
                <set-header name="X-User-ID" exists-action="override">
                    <value>@(((Jwt)context.Variables["validated-jwt"]).Claims.GetValueOrDefault("sub", "unknown"))</value>
                </set-header>
                <set-header name="X-User-Name" exists-action="override">
                    <value>@(((Jwt)context.Variables["validated-jwt"]).Claims.GetValueOrDefault("name", "unknown"))</value>
                </set-header>
            </when>
        </choose>
        
        <!-- Security headers (existing) -->
        <set-header name="X-Content-Type-Options" exists-action="override">
            <value>nosniff</value>
        </set-header>
    </outbound>
    
    <on-error>
        <base />
        <!-- Custom JWT error handling -->
        <choose>
            <when condition="@(context.LastError.Source == "validate-jwt")">
                <return-response>
                    <set-status code="401" reason="Unauthorized" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/problem+json</value>
                    </set-header>
                    <set-body>@{
                        return JsonConvert.SerializeObject(new {
                            type = "https://example.com/problems/invalid-token",
                            title = "Invalid or expired token",
                            status = 401,
                            detail = "The provided JWT token is invalid, expired, or malformed.",
                            instance = context.Request.Url.Path
                        });
                    }</set-body>
                </return-response>
            </when>
        </choose>
    </on-error>
</policies>
```

**Important**: Replace `{your-tenant-id}` with your actual Azure AD tenant ID.

### Apply the Updated Policy

```bash
make apply-api-policy
```

## Step 3: Get Your Tenant ID

```bash
# Get your tenant ID
az account show --query tenantId -o tsv
```

Update the policy file with this tenant ID.

## Step 4: Test JWT Authentication

### Get JWT Token for Testing

Create a test script to get JWT tokens:

```bash
# Create get-token.sh
cat > get-token.sh << 'EOF'
#!/bin/bash

# Configuration (replace with your values)
TENANT_ID="your-tenant-id"
CLIENT_ID="your-app-id"
CLIENT_SECRET="your-client-secret"
SCOPE="api://cars-api/.default"

# Get token
response=$(curl -s -X POST \
  "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=$SCOPE" \
  -d "grant_type=client_credentials")

# Extract access token
token=$(echo $response | jq -r '.access_token')

if [ "$token" != "null" ]; then
    echo "JWT Token obtained successfully!"
    echo "Token: $token"
    echo ""
    echo "Test with:"
    echo "curl -H 'Authorization: Bearer $token' 'https://your-apim.azure-api.net/cars/v1/cars'"
else
    echo "Failed to get token:"
    echo $response | jq .
fi
EOF

chmod +x get-token.sh
```

Run the script:

```bash
./get-token.sh
```

### Test API with JWT Token

```bash
# Test with valid JWT token
JWT_TOKEN="your-jwt-token-here"

curl -v \
  -H "Authorization: Bearer $JWT_TOKEN" \
  "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"
```

You should see:
- `200 OK` response
- `X-User-ID` header in the response
- Cars data returned

### Test Authentication Scenarios

```bash
# Test 1: No authentication (should fail)
curl -v "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"
# Expected: 401 Unauthorized

# Test 2: Invalid JWT token (should fail)
curl -v \
  -H "Authorization: Bearer invalid-token" \
  "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"
# Expected: 401 Unauthorized with JWT error

# Test 3: Subscription key (should work as fallback)
curl -v \
  -H "Ocp-Apim-Subscription-Key: $(grep APIM_PRIMARY_KEY .env | cut -d= -f2)" \
  "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"
# Expected: 200 OK

# Test 4: Valid JWT token (should work)
curl -v \
  -H "Authorization: Bearer $JWT_TOKEN" \
  "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"
# Expected: 200 OK with user context headers
```

## Step 5: Advanced JWT Configuration

### Validate Specific Claims

Add claim validation to ensure tokens have required permissions:

```xml
<validate-jwt header-name="Authorization" failed-validation-httpcode="403">
    <openid-config url="https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration" />
    <audiences>
        <audience>api://cars-api</audience>
    </audiences>
    <required-claims>
        <claim name="roles" match="any" separator=",">
            <value>cars.read</value>
            <value>cars.admin</value>
        </claim>
    </required-claims>
</validate-jwt>
```

### Extract User Information

Store JWT claims in variables for use in policies:

```xml
<set-variable name="userId" value="@(((Jwt)context.Variables["validated-jwt"]).Claims.GetValueOrDefault("sub", ""))" />
<set-variable name="userEmail" value="@(((Jwt)context.Variables["validated-jwt"]).Claims.GetValueOrDefault("email", ""))" />
<set-variable name="userRoles" value="@(((Jwt)context.Variables["validated-jwt"]).Claims.GetValueOrDefault("roles", ""))" />
```

### Role-Based Access Control

Implement different access levels based on JWT claims:

```xml
<choose>
    <when condition="@(((Jwt)context.Variables["validated-jwt"]).Claims.ContainsKey("roles") && ((Jwt)context.Variables["validated-jwt"]).Claims["roles"].Contains("cars.admin"))">
        <!-- Admin access - allow all operations -->
        <set-header name="X-Access-Level" exists-action="override">
            <value>admin</value>
        </set-header>
    </when>
    <when condition="@(((Jwt)context.Variables["validated-jwt"]).Claims.ContainsKey("roles") && ((Jwt)context.Variables["validated-jwt"]).Claims["roles"].Contains("cars.read"))">
        <!-- Read-only access -->
        <choose>
            <when condition="@(context.Request.Method != "GET")">
                <return-response>
                    <set-status code="403" reason="Forbidden" />
                    <set-body>{"error": "Read-only access - GET operations only"}</set-body>
                </return-response>
            </when>
        </choose>
        <set-header name="X-Access-Level" exists-action="override">
            <value>readonly</value>
        </set-header>
    </when>
    <otherwise>
        <return-response>
            <set-status code="403" reason="Forbidden" />
            <set-body>{"error": "Insufficient permissions"}</set-body>
        </return-response>
    </otherwise>
</choose>
```

## Step 6: User Delegation Authentication

For user-delegated scenarios (mobile apps, web apps), configure the OAuth flow differently.

### Configure Delegated Permissions

```bash
# Add User.Read permission for delegated access
az ad app permission add \
  --id $APP_ID \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope

# Grant admin consent
az ad app permission admin-consent --id $APP_ID
```

### Test User-Delegated Flow

For testing user delegation, you'd typically use:

1. **Authorization Code Flow** for web applications
2. **PKCE Flow** for mobile/SPA applications
3. **Device Code Flow** for devices without browsers

Example device code flow for testing:

```bash
# Get device code
response=$(curl -s -X POST \
  "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/devicecode" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "scope=api://cars-api/.default")

echo $response | jq .
```

## Step 7: Monitoring and Debugging

### Add JWT Logging

Log JWT validation results:

```xml
<log-to-eventhub logger-id="jwt-logger" partition-id="0">
    <message>@{
        var jwt = context.Variables.ContainsKey("validated-jwt") ? (Jwt)context.Variables["validated-jwt"] : null;
        return new JObject(
            new JProperty("timestamp", DateTime.UtcNow),
            new JProperty("requestId", context.RequestId),
            new JProperty("hasJWT", jwt != null),
            new JProperty("userId", jwt?.Claims?.GetValueOrDefault("sub", "unknown") ?? "none"),
            new JProperty("tokenExpiry", jwt?.Claims?.GetValueOrDefault("exp", "unknown") ?? "none")
        ).ToString();
    }</message>
</log-to-eventhub>
```

### Debug JWT Issues

Common JWT validation problems:

```bash
# Check token expiry
echo $JWT_TOKEN | cut -d. -f2 | base64 -d | jq .exp

# Verify token signature (basic check)
echo $JWT_TOKEN | cut -d. -f1 | base64 -d | jq .

# Check claims
echo $JWT_TOKEN | cut -d. -f2 | base64 -d | jq .
```

### Test Token Expiry

```bash
# Wait for token to expire, then test
sleep 3600  # Wait 1 hour if token expires in 1 hour
curl -v \
  -H "Authorization: Bearer $JWT_TOKEN" \
  "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"
# Should return 401 with expired token error
```

## Production Considerations

### 1. Token Caching

For high-traffic APIs, consider caching JWT validation results:

```xml
<cache-lookup vary-by-developer="false" vary-by-developer-groups="false">
    <vary-by-header>Authorization</vary-by-header>
</cache-lookup>
<!-- JWT validation here -->
<cache-store duration="300" />  <!-- Cache for 5 minutes -->
```

### 2. Multiple Token Issuers

Support multiple identity providers:

```xml
<validate-jwt header-name="Authorization">
    <openid-config url="https://login.microsoftonline.com/{tenant1}/v2.0/.well-known/openid-configuration" />
    <openid-config url="https://login.microsoftonline.com/{tenant2}/v2.0/.well-known/openid-configuration" />
    <audiences>
        <audience>api://cars-api</audience>
    </audiences>
</validate-jwt>
```

### 3. Rate Limiting per User

Apply different rate limits based on user identity:

```xml
<choose>
    <when condition="@(((Jwt)context.Variables["validated-jwt"]).Claims.GetValueOrDefault("roles", "").Contains("premium"))">
        <rate-limit calls="1000" renewal-period="60" />
    </when>
    <otherwise>
        <rate-limit calls="100" renewal-period="60" />
    </otherwise>
</choose>
```

## Troubleshooting

### Common JWT Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `401 - Invalid signature` | Wrong signing key | Check OpenID config URL |
| `401 - Token expired` | Token past expiry | Get new token |
| `401 - Invalid audience` | Wrong audience claim | Check audience configuration |
| `401 - Invalid issuer` | Wrong issuer claim | Verify issuer URL |

### Debug Steps

1. **Verify Azure AD configuration**:
   ```bash
   az ad app show --id $APP_ID --query "{appId:appId,identifierUris:identifierUris}"
   ```

2. **Check OpenID configuration**:
   ```bash
   curl "https://login.microsoftonline.com/$TENANT_ID/v2.0/.well-known/openid-configuration"
   ```

3. **Validate token manually**:
   ```bash
   # Decode token header and payload
   echo $JWT_TOKEN | cut -d. -f1 | base64 -d | jq .
   echo $JWT_TOKEN | cut -d. -f2 | base64 -d | jq .
   ```

4. **Test with jwt.io**:
   - Copy token to [jwt.io](https://jwt.io)
   - Verify claims and expiry
   - Check signature validation

## What's Next?

You've successfully implemented JWT authentication! Next steps:

1. **🐛 [Debug Policy Issues](/how-to/debug-policy-issues/)** - Learn advanced debugging techniques
2. **📊 [Monitor API Performance](/how-to/monitor-api-performance/)** - Set up comprehensive monitoring
3. **🔒 [Authentication Deep Dive](/explanation/authentication-authorization/)** - Understand auth concepts better
4. **🏭 [Production-Ready APIs](/tutorials/04-production-ready-apis/)** - Prepare for production deployment

## Summary

You've learned to:
- ✅ Set up Azure AD application for JWT tokens
- ✅ Configure JWT validation policies in APIM
- ✅ Implement fallback authentication (JWT + subscription keys)
- ✅ Extract user context from JWT claims
- ✅ Handle authentication errors with RFC 9457 format
- ✅ Test various authentication scenarios
- ✅ Implement role-based access control

JWT authentication provides secure, standardized authentication for your APIs while maintaining user context throughout the request pipeline.

**Ready to debug issues?** Continue to **[Debug Policy Issues →](/how-to/debug-policy-issues)**