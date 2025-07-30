---
title: "How to Configure Client Certificate Authentication"
description: "This guide shows you how to secure your API with client certificate authentication in Azure API Management."
---


This guide shows you how to secure your API with client certificate authentication in Azure API Management.

## Prerequisites

- API deployed to Azure API Management
- Client certificates (either self-signed for testing or CA-issued for production)
- Understanding of TLS/SSL basics
- Completed [Deploy the Cars API](deploy-api.md)

## What You'll Configure

By the end of this guide, your API will:

- Accept only requests with valid client certificates
- Validate certificates based on thumbprint, issuer, or subject
- Return 403 Forbidden for invalid certificates

## Quick Implementation

For a basic thumbprint validation:

```xml
<inbound>
    <choose>
        <when condition="@(context.Request.Certificate == null || context.Request.Certificate.Thumbprint != "YOUR-THUMBPRINT-HERE")">
            <return-response>
                <set-status code="403" reason="Invalid client certificate" />
            </return-response>
        </when>
    </choose>
</inbound>
```

## Step-by-Step Implementation

### Step 1: Generate Test Certificates

For testing, create a self-signed certificate:

```bash
# Generate private key
openssl genrsa -out client.key 2048

# Generate certificate signing request
openssl req -new -key client.key -out client.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=testclient"

# Generate self-signed certificate (valid for 365 days)
openssl x509 -req -days 365 -in client.csr -signkey client.key -out client.crt

# Create PFX file for Windows/Azure
openssl pkcs12 -export -out client.pfx -inkey client.key -in client.crt

# Get the thumbprint
openssl x509 -in client.crt -fingerprint -noout | sed 's/://g' | cut -d'=' -f2
```

### Step 2: Enable Client Certificates (Consumption Tier Only)

If using the Consumption tier:

1. Navigate to your API Management instance
2. Go to **Custom domains**
3. Enable **Negotiate client certificate**

> **Note**: This step is not needed for Developer, Basic, Standard, or Premium tiers.

### Step 3: Upload Certificates to API Management

To validate against multiple certificates:

```bash
# Upload certificate to APIM
az apim certificate create \
  --resource-group $RG \
  --service-name $APIM \
  --certificate-id client-cert-1 \
  --path client.pfx \
  --password 'your-pfx-password'
```

### Step 4: Create Certificate Validation Policy

Create a new policy file:

```bash
touch policies/cars-api/client-cert-validation.xml
```

Add one of these validation approaches:

#### Option A: Validate by Thumbprint

```xml
<policies>
    <inbound>
        <base />
        <choose>
            <when condition="@(context.Request.Certificate == null || 
                             context.Request.Certificate.Thumbprint.ToUpper() != "YOUR-THUMBPRINT-HERE")">
                <return-response>
                    <set-status code="403" reason="Forbidden" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/problem+json</value>
                    </set-header>
                    <set-body>@{
                        return new JObject(
                            new JProperty("type", "https://example.com/probs/invalid-certificate"),
                            new JProperty("title", "Invalid client certificate"),
                            new JProperty("status", 403),
                            new JProperty("detail", "The client certificate is missing or invalid"),
                            new JProperty("instance", context.Request.Url.Path)
                        ).ToString();
                    }</set-body>
                </return-response>
            </when>
        </choose>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

#### Option B: Validate Against Uploaded Certificates

```xml
<policies>
    <inbound>
        <base />
        <choose>
            <when condition="@(context.Request.Certificate == null || 
                             !context.Request.Certificate.Verify() || 
                             !context.Deployment.Certificates.Any(c => c.Value.Thumbprint == context.Request.Certificate.Thumbprint))">
                <return-response>
                    <set-status code="403" reason="Forbidden" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/problem+json</value>
                    </set-header>
                    <set-body>@{
                        return new JObject(
                            new JProperty("type", "https://example.com/probs/invalid-certificate"),
                            new JProperty("title", "Invalid client certificate"),
                            new JProperty("status", 403),
                            new JProperty("detail", "The client certificate is not in the list of trusted certificates"),
                            new JProperty("instance", context.Request.Url.Path)
                        ).ToString();
                    }</set-body>
                </return-response>
            </when>
        </choose>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

#### Option C: Validate Issuer and Subject

```xml
<policies>
    <inbound>
        <base />
        <choose>
            <when condition="@(context.Request.Certificate == null || 
                             context.Request.Certificate.Issuer != "CN=TrustedCA, O=MyOrg, C=US" ||
                             !context.Request.Certificate.SubjectName.Name.Contains("O=PartnerOrg"))">
                <return-response>
                    <set-status code="403" reason="Forbidden" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/problem+json</value>
                    </set-header>
                    <set-body>@{
                        return new JObject(
                            new JProperty("type", "https://example.com/probs/invalid-certificate"),
                            new JProperty("title", "Invalid client certificate"),
                            new JProperty("status", 403),
                            new JProperty("detail", "Certificate issuer or subject is not trusted"),
                            new JProperty("instance", context.Request.Url.Path)
                        ).ToString();
                    }</set-body>
                </return-response>
            </when>
        </choose>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

### Step 5: Apply the Policy

Apply to the entire API:

```bash
make apply-api-policy API_POLICY_FILE=policies/cars-api/client-cert-validation.xml
```

Or to a specific operation:

```bash
make apply-operation-policy \
  OPERATION_ID=getCarById \
  OPERATION_POLICY_FILE=policies/cars-api/client-cert-validation.xml
```

### Step 6: Test with Client Certificate

#### Test with valid certificate

```bash
# Using curl with client certificate
curl -X GET "https://your-apim.azure-api.net/cars/cars/1" \
  --cert client.crt \
  --key client.key \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Accept: application/json"
```

#### Test without certificate (should fail)

```bash
curl -X GET "https://your-apim.azure-api.net/cars/cars/1" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Accept: application/json"
```

Expected response:

```json
{
  "type": "https://example.com/probs/invalid-certificate",
  "title": "Invalid client certificate",
  "status": 403,
  "detail": "The client certificate is missing or invalid",
  "instance": "/cars/cars/1"
}
```

## Advanced Configurations

### Multiple Validation Criteria

Combine multiple checks:

```xml
<when condition="@(
    context.Request.Certificate == null || 
    !context.Request.Certificate.Verify() ||
    context.Request.Certificate.NotAfter < DateTime.Now ||
    context.Request.Certificate.NotBefore > DateTime.Now ||
    !context.Request.Certificate.SubjectName.Name.Contains("O=TrustedOrg")
)">
```

### Certificate Information in Headers

Pass certificate info to backend:

```xml
<inbound>
    <base />
    <set-header name="X-Client-Cert-Subject" exists-action="override">
        <value>@(context.Request.Certificate?.SubjectName.Name ?? "none")</value>
    </set-header>
    <set-header name="X-Client-Cert-Thumbprint" exists-action="override">
        <value>@(context.Request.Certificate?.Thumbprint ?? "none")</value>
    </set-header>
</inbound>
```

### Conditional Certificate Requirements

Require certificates only for certain operations:

```xml
<choose>
    <when condition="@(context.Operation.Id == "deleteCarById" && context.Request.Certificate == null)">
        <return-response>
            <set-status code="403" reason="Certificate required for delete operations" />
        </return-response>
    </when>
</choose>
```

## Troubleshooting

### Certificate Not Detected

1. Ensure TLS termination is at APIM level
2. Check certificate format (PEM vs DER)
3. Verify certificate chain is complete

### Thumbprint Mismatch

```bash
# Get certificate thumbprint
openssl x509 -in client.crt -fingerprint -sha256 -noout

# Compare with APIM
echo "Context thumbprint: @(context.Request.Certificate.Thumbprint)"
```

### Certificate Validation Fails

Check certificate properties:

```xml
<trace source="client-cert-debug">@{
    return new {
        HasCert = context.Request.Certificate != null,
        Thumbprint = context.Request.Certificate?.Thumbprint,
        Subject = context.Request.Certificate?.SubjectName.Name,
        Issuer = context.Request.Certificate?.Issuer,
        NotBefore = context.Request.Certificate?.NotBefore,
        NotAfter = context.Request.Certificate?.NotAfter,
        IsVerified = context.Request.Certificate?.Verify()
    };
}</trace>
```

## Security Best Practices

1. **Never accept self-signed certificates in production**
2. **Always validate certificate expiration**
3. **Use certificate pinning for high-security scenarios**
4. **Combine with other authentication methods**
5. **Regularly rotate certificates**
6. **Monitor certificate expiration dates**

## Next Steps

- [Combine with JWT Authentication](configure-authentication.md)
- [Add IP Filtering](configure-ip-filtering.md)
- [Set Up Mutual TLS](configure-mutual-tls.md)

## References

- [Client Certificate Authentication in APIM](https://docs.microsoft.com/azure/api-management/api-management-howto-mutual-certificates-for-clients)
- [X.509 Certificate Concepts](https://en.wikipedia.org/wiki/X.509)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
