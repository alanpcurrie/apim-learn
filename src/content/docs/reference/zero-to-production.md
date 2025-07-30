---
title: "Zero to Production Cheat Sheet"
description: "Complete command reference to go from zero to production-ready Azure API Management deployment using only make commands."
---

This cheat sheet provides the exact sequence of `make` commands to deploy a production-ready Azure API Management setup. Perfect for CI/CD pipelines or quick deployments.

## 🎯 **Quick Start (5 Minutes)**

```bash
# 1. Setup environment
cp .env.example .env
# Edit .env with your values

# 2. Check prerequisites  
make check-azure-auth
make env-check

# 3. Deploy everything
make provision-azure    # 15-45 minutes
make deploy             # 2-3 minutes
make test-list-cars     # Verify deployment

# 4. Get API keys
make get-keys
```

**Result**: Fully functional APIM instance with deployed API! ✅

---

## 📋 **Complete Production Deployment**

### **Phase 1: Environment Setup**

```bash
# Clone the repository
git clone https://github.com/your-repo/apim-learn.git
cd apim-learn

# Install load testing tools (optional)
# macOS
brew install oha
# Linux/Windows
cargo install oha

# Create environment configuration
cp .env.example .env

# Edit your .env file with real values:
# RG=rg-apim-prod
# APIM=apim-yourcompany-prod
# LOCATION=eastus
# PUBLISHER_EMAIL=admin@yourcompany.com
# PUBLISHER_NAME="Your Company"
vim .env
```

### **Phase 2: Prerequisites Check**

```bash
# Verify Azure CLI authentication
make check-azure-auth

# Install dependencies and validate environment
make install
make env-check

# Validate OpenAPI specification
make lint
```

**Expected Output:**
```
✅ Azure CLI authenticated
✅ All required env vars set
✅ OpenAPI specification passed validation
```

### **Phase 3: Azure Resource Provisioning**

```bash
# Provision all Azure resources (15-45 minutes)
make provision-azure

# Monitor provisioning progress
make check-provisioning

# Wait until status shows "Succeeded"
```

**What this creates:**
- Azure Resource Group
- API Management instance (Consumption tier)
- Developer portal
- Default subscription keys

### **Phase 4: API Deployment**

```bash
# Deploy with full validation
make deploy-safe

# Alternative: Quick deployment
make deploy

# Alternative: Deploy with mock responses (no backend needed)
make deploy-mock
```

**What this deploys:**
- Cars API with OpenAPI specification
- Rate limiting (100 calls/minute)
- CORS policies
- Security headers
- RFC 9457 error handling

### **Phase 5: Testing & Validation**

```bash
# Get subscription keys
make get-keys

# Test all endpoints
make test-list-cars
make test-get-car

# Test error scenarios
curl "https://your-apim.azure-api.net/cars/v1/cars/999"  # 404 test

# Load testing with OHA (optional)
oha -n 100 -c 5 -q 90 \
  -H "Ocp-Apim-Subscription-Key: $(grep APIM_PRIMARY_KEY .env | cut -d= -f2)" \
  "https://$(grep APIM .env | cut -d= -f2).azure-api.net/cars/v1/cars"
```

### **Phase 6: Security Configuration (Optional)**

```bash
# Apply additional security policies
make apply-api-policy

# For JWT authentication (requires Azure AD setup):
# 1. Configure Azure AD application first
# 2. Update policies/cars-api/global.xml with JWT validation
# 3. Apply updated policy
make apply-api-policy
```

---

## ⚡ **Command Quick Reference**

### **Essential Commands**

| Command | Purpose | Time | Prerequisites |
|---------|---------|------|---------------|
| `make help` | Show all commands | 1s | None |
| `make env-check` | Validate environment | 1s | .env file |
| `make check-azure-auth` | Check Azure login | 2s | Azure CLI |
| `make provision-azure` | Create all Azure resources | 15-45min | Auth + env |
| `make deploy` | Deploy API with policies | 30s | APIM instance |
| `make test-list-cars` | Test API functionality | 2s | Deployed API |
| `make get-keys` | Get subscription keys | 5s | APIM instance |
| `make cleanup-azure` | Delete all resources | 30s | Confirmation |

### **Development Commands**

| Command | Purpose | Use Case |
|---------|---------|----------|
| `make install` | Install npm dependencies | First time setup |
| `make lint` | Validate OpenAPI spec | Before deployment |
| `make lint-strict` | Strict validation | CI/CD pipelines |
| `make create-api` | Deploy API only | API updates |
| `make apply-api-policy` | Apply policies only | Policy updates |
| `make show-api` | View API configuration | Debugging |
| `make list-operations` | List API operations | Development |

### **Testing Commands**

| Command | Purpose | What It Tests |
|---------|---------|---------------|
| `make test-list-cars` | Test GET /cars | List endpoint + auth |
| `make test-get-car` | Test GET /cars/1 | Single item + auth |
| `make test-endpoints` | Test with custom headers | Advanced scenarios |

### **Management Commands**

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `make check-provisioning` | Check APIM status | During provisioning |
| `make export-api` | Export API definition | Backup/migration |
| `make clean` | Delete API | Remove API only |
| `make cleanup-azure` | Delete all resources | Full cleanup |

---

## 🏭 **Production Deployment Patterns**

### **CI/CD Pipeline Example**

```yaml
# .github/workflows/deploy.yml
name: Deploy to APIM
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Install Dependencies
        run: make install
      
      - name: Validate API
        run: make lint-strict
      
      - name: Deploy API
        run: make deploy
        env:
          RG: ${{ secrets.RG }}
          APIM: ${{ secrets.APIM }}
          API_ID: cars-api
      
      - name: Test Deployment
        run: make test-list-cars
```

### **Multi-Environment Setup**

```bash
# Development
cp .env.example .env.dev
# Edit with dev values: APIM=apim-dev, RG=rg-dev
make env-check
make deploy

# Staging  
cp .env.example .env.staging
# Edit with staging values: APIM=apim-staging, RG=rg-staging
make env-check
make deploy

# Production
cp .env.example .env.prod
# Edit with prod values: APIM=apim-prod, RG=rg-prod
make env-check
make deploy-safe  # Extra validation for prod
```

### **Blue-Green Deployment**

```bash
# Deploy to blue environment
RG=rg-apim-blue APIM=apim-blue make deploy

# Test blue environment
RG=rg-apim-blue APIM=apim-blue make test-list-cars

# Switch traffic to blue (manual DNS/load balancer change)
# Clean up green environment when confident
RG=rg-apim-green APIM=apim-green make cleanup-azure
```

---

## 🚨 **Troubleshooting Quick Fixes**

### **Common Issues & Solutions**

| Error | Quick Fix |
|-------|-----------|
| `"Not logged in to Azure CLI"` | `az login` |
| `"Missing env vars"` | `cp .env.example .env` and edit |
| `"OpenAPI validation failed"` | `make lint` to see errors |
| `"APIM service not found"` | `make check-provisioning` |
| `"API not found"` | `make create-api` |
| `"401 Unauthorized"` | `make get-keys` and update .env |
| `"429 Too Many Requests"` | Wait 60 seconds for rate limit reset |

### **Emergency Commands**

```bash
# Quick health check
make env-check && make check-provisioning && make test-list-cars

# Force redeploy everything
make apply-api-policy && make create-api

# Get fresh credentials
az login && make get-keys

# Nuclear option (recreate everything)
make cleanup-azure && make provision-azure && make deploy
```

---

## 📊 **Production Readiness Checklist**

### **Before Going Live**

- [ ] **Environment**: Production .env values configured
- [ ] **Security**: JWT authentication configured (not just subscription keys)
- [ ] **Policies**: Rate limiting appropriate for production load
- [ ] **Monitoring**: Azure Monitor configured
- [ ] **Backup**: API definition exported (`make export-api`)
- [ ] **Testing**: All endpoints tested (`make test-list-cars`, `make test-get-car`)
- [ ] **Documentation**: API documentation updated
- [ ] **Keys**: Subscription keys securely stored

### **Post-Deployment**

- [ ] **Monitoring**: Set up alerts for 4xx/5xx errors
- [ ] **Scaling**: Monitor request volumes vs rate limits
- [ ] **Security**: Regular key rotation schedule
- [ ] **Updates**: Process for API version updates
- [ ] **Backup**: Regular export of API configurations

---

## 💰 **Cost Optimization**

### **Consumption Tier Benefits**

```bash
# Check current usage
az apim show --name $APIM --resource-group $RG --query "sku"

# Monitor costs (Consumption tier pricing)
# 0-1M operations/month: FREE
# 1M+ operations: ~$4.20 per million
```

### **Cost-Effective Development**

```bash
# Use mock responses for development (no backend costs)
make deploy-mock

# Clean up when not in use
make cleanup-azure

# Use minimal policies during development
# Add full security only for production
```

---

## 🎯 **Zero to Production in One Command**

For ultimate automation, create a deployment script:

```bash
#!/bin/bash
# deploy-production.sh

set -e  # Exit on any error

echo "🚀 Starting zero-to-production APIM deployment..."

# Validate prerequisites
make check-azure-auth
make env-check
make install
make lint-strict

echo "✅ Prerequisites validated"

# Provision Azure resources
echo "🏗️ Provisioning Azure resources (this takes 15-45 minutes)..."
make provision-azure

# Wait for provisioning to complete
echo "⏳ Waiting for APIM provisioning to complete..."
while true; do
    if make check-provisioning | grep -q "✅ APIM instance is ready"; then
        break
    fi
    echo "Still provisioning... (check status: make check-provisioning)"
    sleep 60
done

echo "✅ Azure resources ready"

# Deploy API
echo "🚗 Deploying Cars API..."
make deploy-safe

# Test deployment  
echo "🧪 Testing deployment..."
make test-list-cars
make test-get-car

# Get keys
echo "🔑 Getting subscription keys..."
make get-keys

echo "🎉 Production deployment complete!"
echo "📋 Next steps:"
echo "   1. Configure JWT authentication if needed"
echo "   2. Set up monitoring and alerts"
echo "   3. Update rate limits for production load"
echo "   4. Configure custom domain (optional)"
```

Run with:
```bash
chmod +x deploy-production.sh
./deploy-production.sh
```

## 🎓 **Summary**

This cheat sheet covers:

- ✅ **5-minute quick start** for immediate deployment
- ✅ **Complete production flow** with all steps
- ✅ **Command reference** for all scenarios
- ✅ **CI/CD integration** examples
- ✅ **Multi-environment** deployment patterns
- ✅ **Troubleshooting** quick fixes
- ✅ **Production readiness** checklist
- ✅ **Cost optimization** strategies
- ✅ **One-command deployment** automation

**You now have everything needed to deploy production-ready Azure API Management with just `make` commands!** 🚀

---

*Need help? Check our [Debug Policy Issues](/how-to/debug-policy-issues) guide or [Architecture Overview](/explanation/architecture-overview) for deeper understanding.*