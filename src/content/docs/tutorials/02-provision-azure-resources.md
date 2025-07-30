---
title: "Provision Azure Resources"
description: "Learn how to create and provision your Azure Resource Group and API Management instance using Azure CLI and Makefiles."
---

Before you can deploy APIs to Azure API Management, you need to provision the underlying Azure resources. This tutorial walks you through creating a Resource Group and API Management instance using our automated Makefile commands.

## Prerequisites

- Azure CLI installed and configured
- Azure subscription with appropriate permissions
- Cloned apim-learn repository
- Basic understanding of command line tools

## 🏗️ What We'll Create

This tutorial will provision:
- **Azure Resource Group** - Container for all your APIM resources
- **Azure API Management Instance** - The APIM service (Consumption tier)
- **Subscription keys** - For testing your APIs

:::note[Time Requirement]
The APIM instance creation takes **15-45 minutes** to complete. Azure needs time to provision the underlying infrastructure.
:::

## Step 1: Environment Setup

First, copy the example environment file and configure it with your values:

```bash
# Copy the environment template
cp .env.example .env
```

Edit the `.env` file with your specific values:

```bash
# Azure Resource Configuration
RG=rg-apim-yourname              # Resource group name
APIM=apim-yourname-demo          # APIM instance name (must be globally unique)
API_ID=cars-api

# Azure Location (choose closest to you)
LOCATION=eastus

# Publisher Information (required for APIM)
PUBLISHER_EMAIL=your-email@example.com
PUBLISHER_NAME=Your Name

# API Configuration
API_VERSION=v1
API_PATH=cars
OPENAPI_SPEC=openapi/cars-api.yaml
API_POLICY_FILE=policies/cars-api/global.xml
```

:::caution[APIM Name Must Be Unique]
The `APIM` name must be globally unique across all of Azure. Consider using your name or company prefix: `apim-yourname-demo`
:::

## Step 2: Verify Azure Authentication

Check that you're logged into Azure CLI:

```bash
make check-azure-auth
```

If not authenticated, log in:

```bash
az login
```

## Step 3: Provision Resources

You can provision resources individually or all at once:

### Option A: Full Provisioning (Recommended)

Run the complete provisioning workflow:

```bash
make provision-azure
```

This will:
1. Show you what resources will be created
2. Ask for confirmation
3. Create the resource group
4. Start APIM instance creation
5. Provide monitoring instructions

### Option B: Step-by-Step Provisioning

If you prefer more control, provision resources individually:

```bash
# 1. Create resource group
make create-resource-group

# 2. Create APIM instance
make create-apim
```

## Step 4: Monitor Provisioning Progress

Since APIM creation takes 15-45 minutes, monitor the progress:

```bash
make check-provisioning
```

Example output:
```
🔍 Checking provisioning status...
Name            Location  Sku        State       GatewayUrl
--------------  --------  ---------  ----------  ------------------------------------------
apim-demo-fast  eastus    Developer  Creating    
⏳ APIM instance is still being created...
```

When complete, you'll see:
```
Name            Location  Sku        State      GatewayUrl
--------------  --------  ---------  ---------  ------------------------------------------
apim-demo-fast  eastus    Developer  Succeeded  https://apim-demo-fast.azure-api.net
✅ APIM instance is ready!
🌐 Gateway URL: https://apim-demo-fast.azure-api.net
```

## Step 5: Verify Resources

Once provisioning is complete, verify your resources are ready:

```bash
# Check APIM status
make check-provisioning

# View your resource group in Azure Portal
az group show --name $RG --query "{name:name,location:location,provisioningState:properties.provisioningState}" -o table
```

## What's Next?

Now that your Azure resources are provisioned, you're ready to deploy your first API:

### **Immediate Next Steps:**
1. **🚗 [Deploy the Cars API](/guides/deploy-api/)** - Deploy your first API to the APIM instance you just created
2. **🧪 [Test Your API](/how-to/test-endpoints/)** - Verify your deployment works correctly
3. **📊 [Learn Policy Fundamentals](/tutorials/03-understanding-policies/)** - Add rate limiting, security, and more

### **Learning Path Overview:**
```
✅ Environment Setup
✅ Provision Azure Resources  
→ 🎯 Deploy Your First API (next!)
→ Test & Validate
→ Configure Policies
→ Add Authentication
→ Production Ready
```

**Ready to deploy?** Continue to **[Deploy the Cars API →](/guides/deploy-api/)**

## 🛠️ Troubleshooting

### Authentication Issues
```bash
# Re-login to Azure
az login

# Check which subscription you're using
az account show
```

### APIM Name Conflicts
If you get naming conflicts, update your `.env` file with a more unique name:
```bash
APIM=apim-yourcompany-yourname-$(date +%m%d)
```

### Permissions Issues
Ensure your Azure account has:
- Contributor role on the subscription
- Permission to create resource groups
- Permission to create API Management instances

## 💰 Cost Considerations

The Consumption tier APIM instance is **pay-per-request**, making it perfect for learning:

### Consumption Tier Pricing
- **0-1 million API operations per month** - **FREE** ✨
- **1+ million API operations** - $0.042 per 10,000 operations (~$4.20 per million)
- **No base monthly cost** - Pay only for what you use
- **Auto-scaling** - Scales automatically based on usage

### Why This Works for Learning

During typical learning activities, you'll make:
- **Testing endpoints**: ~50-100 requests per session
- **Following tutorials**: ~200-500 requests total
- **Experimenting**: ~1,000-5,000 requests over weeks

**Result**: You'll likely stay well within the **1 million free operations per month**, meaning **$0 cost** for most learning scenarios! 🎉

Even if you exceed 1 million operations (very unlikely during learning), the cost is minimal:
- 2 million operations = ~$4.20/month
- 5 million operations = ~$16.80/month

### Comparison to Other Tiers
- **Developer tier**: $50-60/month base cost (regardless of usage)  
- **Basic tier**: $90+/month base cost
- **Consumption tier**: $0 for most learning scenarios

The Consumption tier means you typically won't incur significant costs during learning, but it's still good practice to clean up when done:
```bash
make cleanup-azure
```

## Summary

You've successfully:
- ✅ Configured your Azure environment
- ✅ Provisioned a Resource Group
- ✅ Created an APIM instance
- ✅ Learned to monitor provisioning status

Your Azure API Management instance is now ready for API deployments!