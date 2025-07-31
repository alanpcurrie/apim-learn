---
title: "Clean Up Azure Resources"
description: "Learn how to safely remove Azure API Management resources and avoid ongoing charges."
---

When you're done learning or experimenting with Azure API Management, it's important to clean up your resources to avoid ongoing charges. This guide covers multiple cleanup methods.

## 💰 Why Clean Up?

The Consumption tier APIM billing model is very learner-friendly:

### Consumption Tier Billing
- **0-1 million API operations per month** - **FREE** ✨  
- **1+ million operations** - $0.042 per 10,000 operations (~$4.20 per million)
- **No charges when idle** - No base monthly cost

### For Learning Scenarios
Most learning activities use only hundreds or thousands of API calls, staying well within the **1 million free operations per month**. However, it's still good practice to clean up resources when done to:

- Avoid any accidental usage beyond free tier
- Keep your Azure account organized
- Practice good resource management habits

## 🛡️ Safety First

All cleanup methods include safety confirmations to prevent accidental deletions. You'll be prompted to confirm before any resources are deleted.

## Method 1: Using Make Commands (Recommended)

The simplest way to clean up all resources at once.

### Full Resource Group Cleanup

```bash
make cleanup-azure
```

**What it does:**
- Deletes the entire resource group and all contained resources
- Includes APIM instance, policies, APIs, subscriptions
- Most thorough cleanup method

**Interactive confirmation:**

```bash
⚠️ WARNING: This will DELETE all Azure resources!
📋 Resources to be deleted:
   • Resource Group: rg-apim-demo
   • APIM Instance: apim-demo
   • ALL resources within the resource group

Are you sure? Type 'DELETE' to confirm: DELETE
```

**Safety features:**
- Requires typing "DELETE" exactly
- Shows exactly what will be deleted
- Uses `--no-wait` for background deletion

## Method 2: Selective API Cleanup

If you want to keep the APIM instance but remove specific APIs.

### Delete Single API

```bash
make clean
```

**What it does:**
- Removes only the Cars API from APIM
- Keeps APIM instance running
- Preserves other APIs and configurations

**Interactive confirmation:**

```bash
WARNING: This will delete the API 'cars-api' from APIM service 'apim-demo'
Press Ctrl+C to cancel, or Enter to continue...
```

### Delete API Policies

```bash
make delete-policy
```

**What it does:**
- Removes API-level policies
- Keeps the API definition and endpoints
- Useful for testing different policy configurations

## Method 3: Azure CLI Direct Commands

For more granular control over resource deletion.

### Delete APIM Instance Only

```bash
# Delete APIM instance but keep resource group
az apim delete \
  --resource-group $RG \
  --name $APIM \
  --yes \
  --no-wait
```

### Delete Resource Group

```bash
# Delete entire resource group
az group delete \
  --name $RG \
  --yes \
  --no-wait
```

### Check Deletion Progress

```bash
# Monitor resource group deletion
az group show --name $RG --query "properties.provisioningState" -o tsv

# Monitor APIM deletion (if keeping resource group)
az apim show --name $APIM --resource-group $RG --query "provisioningState" -o tsv
```

## Method 4: Azure Portal

For visual confirmation and detailed resource management.

### Steps:

1. **Navigate to Azure Portal**
   - Go to [portal.azure.com](https://portal.azure.com)
   - Sign in with your Azure account

2. **Find Your Resource Group**
   - Search for "Resource groups"
   - Click on your resource group (e.g., `rg-apim-demo`)

3. **Review Resources**
   - See all resources that will be deleted
   - Note any additional resources you might have created

4. **Delete Resource Group**
   - Click "Delete resource group"
   - Type the resource group name to confirm
   - Click "Delete"

### Selective Portal Deletion

To delete only the APIM instance:

1. Navigate to your APIM instance
2. Click "Delete" in the top menu
3. Confirm the deletion
4. Wait for completion (can take several minutes)

## Verification

After cleanup, verify resources are gone:

### Check Resource Group

```bash
# Should return error if deleted
az group show --name $RG
```

### Check APIM Instance

```bash
# Should return error if deleted
az apim show --name $APIM --resource-group $RG
```

### List All Resources

```bash
# Should show empty or no resource group
az resource list --resource-group $RG --output table
```

## Cost Optimization Strategies

### Instead of Full Deletion

If you plan to continue learning later:

#### Stop APIM Instance (Not Available in Consumption Tier)

The Consumption tier doesn't support start/stop operations. However, since it's pay-per-request, there are no ongoing charges when not in use.

#### Consumption Tier Benefits

Our setup already uses the Consumption tier which is perfect for learning:

**Benefits:**
- No base monthly charge
- Pay only for requests (~$3.50 per million requests)
- Auto-scales based on usage
- No charges when not actively making requests

## Troubleshooting Cleanup

### "Resource group not found"

This means cleanup was successful or the resource group never existed.

### "Cannot delete resource group with existing resources"

Some resources might have deletion protection:

```bash
# Force delete all resources
az resource delete --ids $(az resource list --resource-group $RG --query "[].id" -o tsv) --force-deletion-types Microsoft.ApiManagement/service
```

### "Operation is not allowed"

Check your permissions:

```bash
# Verify you have contributor access
az role assignment list --assignee $(az account show --query user.name -o tsv) --output table
```

### Deletion Taking Too Long

APIM deletion can take 15-30 minutes:

```bash
# Check deletion status
az group show --name $RG --query "properties.provisioningState" -o tsv
```

Expected states:
- `Deleting` - In progress
- `NotFound` - Completed successfully

## Automation Scripts

### Cleanup All Learning Resources

Create a script to clean up multiple learning resource groups:

```bash
#!/bin/bash
# cleanup-all-apim.sh

RESOURCE_GROUPS=(
  "rg-apim-learning"
  "rg-apim-demo"
  "rg-apim-test"
)

for rg in "${RESOURCE_GROUPS[@]}"; do
  echo "Checking resource group: $rg"
  if az group show --name "$rg" >/dev/null 2>&1; then
    echo "Deleting resource group: $rg"
    az group delete --name "$rg" --yes --no-wait
  else
    echo "Resource group $rg does not exist"
  fi
done
```

### Scheduled Cleanup

Use Azure Automation or GitHub Actions to automatically clean up resources:

```yaml
# .github/workflows/cleanup.yml
name: Weekly Cleanup
on:
  schedule:
    - cron: '0 0 * * 0'  # Every Sunday at midnight

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Delete Demo Resources
        run: |
          az group delete --name rg-apim-demo --yes --no-wait || true
```

## Best Practices

### Before Learning Sessions

1. **Set Calendar Reminders** - Clean up after learning sessions
2. **Use Descriptive Names** - Include dates in resource names
3. **Document Resources** - Keep track of what you create

### During Learning

1. **Monitor Costs** - Check Azure cost analysis regularly
2. **Use Budgets** - Set up spending alerts
3. **Tag Resources** - Tag with project/learning identifiers

### After Learning

1. **Immediate Cleanup** - Don't wait to clean up
2. **Verify Deletion** - Confirm resources are actually deleted
3. **Check Bill** - Monitor next month's charges

## Cost Monitoring

Set up alerts to avoid surprise charges:

### Budget Alert

```bash
# Create budget with alert
az consumption budget create \
  --budget-name "APIM-Learning" \
  --amount 100 \
  --time-grain Monthly \
  --start-date $(date -d "first day of this month" +%Y-%m-01) \
  --end-date $(date -d "first day of next month" +%Y-%m-01) \
  --notification-emails your-email@example.com \
  --threshold 80
```

### Cost Alerts

Enable cost alerts in the Azure portal:
1. Go to Cost Management + Billing
2. Set up budget alerts
3. Configure email notifications

## Summary

Resource cleanup options ranked by thoroughness:

1. **`make cleanup-azure`** - Complete cleanup, most recommended
2. **Azure Portal** - Visual confirmation, good for beginners
3. **Azure CLI** - Flexible, good for automation
4. **`make clean`** - API-only cleanup, keeps APIM running

Remember: The Developer tier APIM costs ~$50-60/month whether you use it or not. Clean up promptly to avoid unnecessary charges!