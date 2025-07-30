---
title: "Debug Policy Issues"
description: "Learn how to troubleshoot and debug Azure API Management policy problems using tracing, logging, and systematic debugging techniques."
---

Debugging APIM policies can be challenging due to their execution within Azure's infrastructure. This guide teaches you systematic approaches to identify, diagnose, and fix policy issues.

## Common Policy Problems

Understanding common issues helps you debug faster:

| Problem Type | Symptoms | Common Causes |
|--------------|----------|---------------|
| **Policy Syntax Errors** | 500 errors, policy not applied | Invalid XML, wrong expressions |
| **Authentication Issues** | 401/403 errors | JWT config, key validation |
| **Performance Problems** | Slow responses | Heavy processing, external calls |
| **Logic Errors** | Unexpected behavior | Wrong conditions, variable issues |
| **Integration Failures** | Backend errors | Connectivity, transformation issues |

## Debugging Tools and Techniques

### 1. Policy Tracing

The most powerful debugging tool for policies.

#### Enable Trace Policy

Add trace statements to your policy:

```xml
<policies>
    <inbound>
        <base />
        <!-- Debug trace at start -->
        <trace source="cars-api-debug">
            <message>Request started: @(context.Request.Method) @(context.Request.Url)</message>
            <metadata name="timestamp" value="@(DateTime.UtcNow)" />
            <metadata name="requestId" value="@(context.RequestId)" />
        </trace>
        
        <!-- Your existing policies -->
        <validate-jwt header-name="Authorization">
            <!-- JWT config -->
        </validate-jwt>
        
        <!-- Trace after JWT validation -->
        <trace source="cars-api-debug">
            <message>JWT validation completed successfully</message>
            <metadata name="hasValidJWT" value="@(context.Variables.ContainsKey("validated-jwt"))" />
        </trace>
        
        <rate-limit calls="100" renewal-period="60" />
        
        <!-- Trace after rate limiting -->
        <trace source="cars-api-debug">
            <message>Rate limiting passed</message>
        </trace>
    </inbound>
    
    <backend>
        <base />
        <!-- Trace before backend call -->
        <trace source="cars-api-debug">
            <message>Calling backend service</message>
        </trace>
    </backend>
    
    <outbound>
        <base />
        <!-- Trace response -->
        <trace source="cars-api-debug">
            <message>Response ready: @(context.Response.StatusCode)</message>
            <metadata name="responseTime" value="@(context.Elapsed.TotalMilliseconds)" />
        </trace>
    </outbound>
    
    <on-error>
        <base />
        <!-- Trace errors -->
        <trace source="cars-api-debug">
            <message>Error occurred: @(context.LastError.Message)</message>
            <metadata name="errorSource" value="@(context.LastError.Source)" />
            <metadata name="errorReason" value="@(context.LastError.Reason)" />
        </trace>
    </on-error>
</policies>
```

#### View Trace Output

```bash
# Apply policy with tracing
make apply-api-policy

# Make a test request
curl -v \
  -H "Ocp-Apim-Subscription-Key: $(grep APIM_PRIMARY_KEY .env | cut -d= -f2)" \
  "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"

# View traces in Azure Portal:
# 1. Go to your APIM instance
# 2. Navigate to APIs > Cars API > Test
# 3. Send a test request
# 4. View the "Trace" tab in the response
```

### 2. Variable Inspection

Debug by examining context variables:

```xml
<!-- Inspect all request headers -->
<trace source="headers-debug">
    <message>Request Headers: @{
        var headers = new JObject();
        foreach(var header in context.Request.Headers) {
            headers.Add(header.Key, string.Join(",", header.Value));
        }
        return headers.ToString();
    }</message>
</trace>

<!-- Inspect specific variables -->
<trace source="variables-debug">
    <message>Current Variables: @{
        var vars = new JObject();
        foreach(var var in context.Variables) {
            vars.Add(var.Key, var.Value?.ToString() ?? "null");
        }
        return vars.ToString();
    }</message>
</trace>

<!-- Inspect JWT claims -->
<trace source="jwt-debug">
    <message>JWT Claims: @{
        if(context.Variables.ContainsKey("validated-jwt")) {
            var jwt = (Jwt)context.Variables["validated-jwt"];
            var claims = new JObject();
            foreach(var claim in jwt.Claims) {
                claims.Add(claim.Key, claim.Value);
            }
            return claims.ToString();
        }
        return "No JWT found";
    }</message>
</trace>
```

### 3. Conditional Debugging

Debug specific scenarios:

```xml
<!-- Debug only failed requests -->
<choose>
    <when condition="@(context.Response.StatusCode >= 400)">
        <trace source="error-debug">
            <message>Error Response Debug</message>
            <metadata name="statusCode" value="@(context.Response.StatusCode)" />
            <metadata name="requestBody" value="@(context.Request.Body?.As<string>(preserveContent: true) ?? "no body")" />
            <metadata name="responseBody" value="@(context.Response.Body?.As<string>(preserveContent: true) ?? "no body")" />
        </trace>
    </when>
</choose>

<!-- Debug specific users -->
<choose>
    <when condition="@(context.Request.Headers.GetValueOrDefault("X-Debug-User", "") == "true")">
        <trace source="user-debug">
            <message>Debug mode enabled for user request</message>
            <metadata name="allHeaders" value="@(string.Join(", ", context.Request.Headers.Select(h => h.Key + ":" + string.Join(",", h.Value))))" />
        </trace>
    </when>
</choose>
```

## Systematic Debugging Process

### Step 1: Identify the Problem Area

Use traces to narrow down where issues occur:

```xml
<!-- Add checkpoint traces -->
<policies>
    <inbound>
        <base />
        <trace source="checkpoint"><message>CHECKPOINT 1: Inbound start</message></trace>
        
        <!-- Policy block 1 -->
        <validate-jwt header-name="Authorization">
            <!-- config -->
        </validate-jwt>
        <trace source="checkpoint"><message>CHECKPOINT 2: JWT validation done</message></trace>
        
        <!-- Policy block 2 -->
        <rate-limit calls="100" renewal-period="60" />
        <trace source="checkpoint"><message>CHECKPOINT 3: Rate limiting done</message></trace>
        
        <!-- Continue for each policy block -->
    </inbound>
</policies>
```

### Step 2: Isolate the Failing Policy

Temporarily disable policies to isolate issues:

```xml
<!-- Comment out suspected problematic policies -->
<policies>
    <inbound>
        <base />
        
        <!-- Temporarily disable JWT validation -->
        <!--
        <validate-jwt header-name="Authorization">
            <openid-config url="..." />
        </validate-jwt>
        -->
        
        <!-- Test with just this policy -->
        <rate-limit calls="100" renewal-period="60" />
        
        <trace source="isolation-test">
            <message>Testing with minimal policies</message>
        </trace>
    </inbound>
</policies>
```

### Step 3: Test Incrementally

Add policies back one by one:

```bash
# Test 1: Minimal policy (just rate limiting)
make apply-api-policy
curl -H "Ocp-Apim-Subscription-Key: $KEY" "$API_URL/cars"

# Test 2: Add CORS
# (edit policy, add CORS back)
make apply-api-policy
curl -H "Ocp-Apim-Subscription-Key: $KEY" "$API_URL/cars"

# Test 3: Add JWT validation
# (edit policy, add JWT back)
make apply-api-policy
curl -H "Authorization: Bearer $JWT_TOKEN" "$API_URL/cars"
```

## Common Error Scenarios

### 1. JWT Validation Issues

**Problem**: JWT validation failing unexpectedly

**Debug Steps**:

```xml
<!-- Debug JWT validation -->
<validate-jwt header-name="Authorization" failed-validation-httpcode="401">
    <openid-config url="https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration" />
    <audiences>
        <audience>api://cars-api</audience>
    </audiences>
</validate-jwt>

<!-- Add debugging after JWT validation -->
<trace source="jwt-validation-debug">
    <message>JWT Validation Results: @{
        var jwt = context.Variables.ContainsKey("validated-jwt") ? (Jwt)context.Variables["validated-jwt"] : null;
        if(jwt != null) {
            return new JObject(
                new JProperty("isValid", true),
                new JProperty("issuer", jwt.Claims.GetValueOrDefault("iss", "unknown")),
                new JProperty("audience", jwt.Claims.GetValueOrDefault("aud", "unknown")),
                new JProperty("expiry", jwt.Claims.GetValueOrDefault("exp", "unknown")),
                new JProperty("subject", jwt.Claims.GetValueOrDefault("sub", "unknown"))
            ).ToString();
        }
        return "JWT validation failed or no JWT found";
    }</message>
</trace>
```

**Common Issues**:
```bash
# Check token expiry
echo $JWT_TOKEN | cut -d. -f2 | base64 -d | jq .exp | xargs -I {} date -d @{}

# Verify audience
echo $JWT_TOKEN | cut -d. -f2 | base64 -d | jq .aud

# Check issuer
echo $JWT_TOKEN | cut -d. -f2 | base64 -d | jq .iss
```

### 2. Rate Limiting Problems

**Problem**: Rate limiting behaving unexpectedly

**Debug Steps**:

```xml
<!-- Debug rate limiting -->
<rate-limit calls="10" renewal-period="60" 
           remaining-calls-header-name="X-RateLimit-Remaining"
           total-calls-header-name="X-RateLimit-Limit"
           renewal-period-header-name="X-RateLimit-Reset" />

<!-- Add rate limit debugging -->
<trace source="rate-limit-debug">
    <message>Rate Limit Check</message>
    <metadata name="remainingCalls" value="@(context.Response.Headers.GetValueOrDefault("X-RateLimit-Remaining", "unknown"))" />
    <metadata name="totalCalls" value="@(context.Response.Headers.GetValueOrDefault("X-RateLimit-Limit", "unknown"))" />
</trace>
```

**Test Rate Limiting**:
```bash
# Test rate limiting with debug headers
for i in {1..15}; do
  echo "Request $i:"
  curl -s -I \
    -H "Ocp-Apim-Subscription-Key: $(grep APIM_PRIMARY_KEY .env | cut -d= -f2)" \
    "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars" \
    | grep -E "(HTTP|X-RateLimit)"
  echo "---"
done
```

### 3. Backend Connectivity Issues

**Problem**: Backend calls failing

**Debug Steps**:

```xml
<!-- Debug backend calls -->
<trace source="backend-debug">
    <message>Backend Call Debug</message>
    <metadata name="backendUrl" value="@(context.Request.Url.ToString())" />
    <metadata name="method" value="@(context.Request.Method)" />
    <metadata name="headers" value="@(string.Join(", ", context.Request.Headers.Select(h => h.Key + "=" + string.Join(",", h.Value))))" />
</trace>

<!-- Test backend connectivity -->
<send-request mode="new" response-variable-name="backend-test" timeout="10" ignore-error="true">
    <set-url>@(context.Request.Url.ToString())</set-url>
    <set-method>GET</set-method>
</send-request>

<trace source="backend-test">
    <message>Backend Test Result: @{
        var response = (IResponse)context.Variables["backend-test"];
        return new JObject(
            new JProperty("statusCode", response.StatusCode),
            new JProperty("body", response.Body.As<string>()),
            new JProperty("headers", string.Join(", ", response.Headers.Select(h => h.Key + "=" + string.Join(",", h.Value))))
        ).ToString();
    }</message>
</trace>
```

### 4. Policy Expression Errors

**Problem**: Policy expressions causing runtime errors

**Debug Steps**:

```xml
<!-- Safe policy expressions with error handling -->
<set-variable name="userId" value="@{
    try {
        if(context.Variables.ContainsKey("validated-jwt")) {
            var jwt = (Jwt)context.Variables["validated-jwt"];
            return jwt.Claims.GetValueOrDefault("sub", "unknown");
        }
        return "no-jwt";
    }
    catch(Exception ex) {
        return "error: " + ex.Message;
    }
}" />

<trace source="expression-debug">
    <message>Expression Result: @(context.Variables.GetValueOrDefault("userId", "not-set"))</message>
</trace>
```

## Advanced Debugging Techniques

### 1. Mock Responses for Testing

Isolate issues by mocking responses:

```xml
<!-- Replace backend with mock for debugging -->
<policies>
    <inbound>
        <base />
        <!-- Your policies here -->
        
        <!-- Mock the backend response -->
        <mock-response status-code="200" content-type="application/json">
            <![CDATA[{
                "debug": {
                    "requestId": "@(context.RequestId)",
                    "timestamp": "@(DateTime.UtcNow)",
                    "method": "@(context.Request.Method)",
                    "url": "@(context.Request.Url)",
                    "hasJWT": "@(context.Variables.ContainsKey("validated-jwt"))",
                    "subscriptionId": "@(context.Subscription?.Id ?? "none")"
                },
                "message": "Mock response - policies working correctly"
            }]]>
        </mock-response>
    </inbound>
</policies>
```

### 2. External Logging

Send debug information to external systems:

```xml
<!-- Log to external webhook for debugging -->
<send-one-way-request mode="new">
    <set-url>https://webhook.site/your-unique-url</set-url>
    <set-method>POST</set-method>
    <set-header name="Content-Type" exists-action="override">
        <value>application/json</value>
    </set-header>
    <set-body>@{
        return JsonConvert.SerializeObject(new {
            timestamp = DateTime.UtcNow,
            requestId = context.RequestId,
            method = context.Request.Method,
            url = context.Request.Url.ToString(),
            statusCode = context.Response?.StatusCode ?? 0,
            error = context.LastError?.Message ?? "none"
        });
    }</set-body>
</send-one-way-request>
```

### 3. Conditional Policy Execution

Debug specific conditions:

```xml
<!-- Only apply policies for debug requests -->
<choose>
    <when condition="@(context.Request.Headers.GetValueOrDefault("X-Debug", "") == "true")">
        <!-- Debug version of policies -->
        <trace source="debug-mode">
            <message>Debug mode active - detailed logging enabled</message>
        </trace>
        
        <!-- More verbose policies -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
            <!-- config -->
        </validate-jwt>
        
        <trace source="debug-mode">
            <message>JWT validation in debug mode completed</message>
        </trace>
    </when>
    <otherwise>
        <!-- Production policies (minimal logging) -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
            <!-- config -->
        </validate-jwt>
    </otherwise>
</choose>
```

Test with debug mode:

```bash
# Normal request
curl -H "Ocp-Apim-Subscription-Key: $KEY" "$API_URL/cars"

# Debug request
curl -H "Ocp-Apim-Subscription-Key: $KEY" -H "X-Debug: true" "$API_URL/cars"
```

## Policy Validation Tools

### 1. XML Syntax Validation

```bash
# Validate XML syntax
xmllint --noout policies/cars-api/global.xml

# Format XML for readability
xmllint --format policies/cars-api/global.xml
```

### 2. Policy Expression Testing

Create a test policy to validate expressions:

```xml
<policies>
    <inbound>
        <base />
        <!-- Test expressions -->
        <set-variable name="test1" value="@(DateTime.UtcNow.ToString())" />
        <set-variable name="test2" value="@(context.Request.Headers.Count)" />
        <set-variable name="test3" value="@(context.Request.Url.Query)" />
        
        <trace source="expression-test">
            <message>Expression Tests: @{
                return new JObject(
                    new JProperty("currentTime", context.Variables["test1"]),
                    new JProperty("headerCount", context.Variables["test2"]),
                    new JProperty("queryString", context.Variables["test3"])
                ).ToString();
            }</message>
        </trace>
        
        <!-- Return immediately for testing -->
        <return-response>
            <set-status code="200" reason="OK" />
            <set-body>Expression test completed - check traces</set-body>
        </return-response>
    </inbound>
</policies>
```

### 3. Performance Debugging

Measure policy execution time:

```xml
<policies>
    <inbound>
        <base />
        <!-- Start timer -->
        <set-variable name="startTime" value="@(DateTime.UtcNow)" />
        
        <!-- Your expensive policy -->
        <validate-jwt header-name="Authorization">
            <!-- config -->
        </validate-jwt>
        
        <!-- Measure time -->
        <trace source="performance">
            <message>JWT validation took: @(DateTime.UtcNow.Subtract((DateTime)context.Variables["startTime"]).TotalMilliseconds)ms</message>
        </trace>
    </inbound>
</policies>
```

## Debugging Checklist

When debugging policy issues, follow this systematic checklist:

### ✅ **Initial Investigation**
- [ ] Check Azure Portal for policy application errors
- [ ] Verify XML syntax with `xmllint`
- [ ] Review recent policy changes
- [ ] Check API status and health

### ✅ **Add Debugging**
- [ ] Add trace statements at key points
- [ ] Log request/response details
- [ ] Capture variable states
- [ ] Add error handling traces

### ✅ **Test Systematically**
- [ ] Test with minimal policy first
- [ ] Add policies incrementally
- [ ] Test different request scenarios
- [ ] Verify expected vs actual behavior

### ✅ **Performance Check**
- [ ] Measure policy execution times
- [ ] Check for expensive operations
- [ ] Monitor external service calls
- [ ] Validate caching effectiveness

### ✅ **Production Readiness**
- [ ] Remove debug traces from production
- [ ] Implement proper error handling
- [ ] Add monitoring and alerting
- [ ] Document known issues and solutions

## Common Debug Commands

```bash
# Quick policy syntax check
xmllint --noout policies/cars-api/global.xml && echo "✅ XML is valid"

# Apply policy and test immediately
make apply-api-policy && \
curl -v -H "Ocp-Apim-Subscription-Key: $(grep APIM_PRIMARY_KEY .env | cut -d= -f2)" \
"https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"

# Test all authentication methods
echo "Testing subscription key..."
curl -s -w "Status: %{http_code}\n" -H "Ocp-Apim-Subscription-Key: $KEY" "$API_URL/cars" -o /dev/null

echo "Testing JWT token..."
curl -s -w "Status: %{http_code}\n" -H "Authorization: Bearer $JWT_TOKEN" "$API_URL/cars" -o /dev/null

echo "Testing no auth..."
curl -s -w "Status: %{http_code}\n" "$API_URL/cars" -o /dev/null

# Monitor policy performance
time curl -H "Ocp-Apim-Subscription-Key: $KEY" "$API_URL/cars" -o /dev/null
```

## What's Next?

You're now equipped with comprehensive debugging skills! Next steps:

1. **📊 [Monitor API Performance](/how-to/monitor-api-performance/)** - Set up proactive monitoring
2. **🔒 [Authentication Deep Dive](/explanation/authentication-authorization/)** - Master auth concepts
3. **🏭 [Production-Ready APIs](/tutorials/04-production-ready-apis/)** - Prepare for production
4. **📋 [APIM Best Practices](/explanation/apim-best-practices/)** - Learn industry standards

## Summary

You've learned to:
- ✅ Use trace policies for systematic debugging
- ✅ Isolate and identify problematic policies
- ✅ Debug JWT validation and authentication issues
- ✅ Troubleshoot rate limiting and backend connectivity
- ✅ Validate policy expressions and XML syntax
- ✅ Measure and optimize policy performance
- ✅ Implement conditional debugging for production environments

Effective debugging saves hours of troubleshooting and ensures reliable API operations.

**Ready for production?** Continue to **[Zero to Production Cheat Sheet →](/reference/zero-to-production)**