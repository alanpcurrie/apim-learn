---
title: "Clean Up Terraform Infrastructure"
description: "Learn how to safely destroy Terraform-managed Azure API Management resources and avoid ongoing charges."
---

# Clean Up Terraform Infrastructure

When you're done with your Terraform-managed Azure API Management infrastructure, it's crucial to clean up resources properly to avoid ongoing charges. This guide covers safe cleanup methods for Terraform-deployed resources.

## 💰 Cost Considerations

### Terraform vs Manual Resources

Terraform-managed resources require special consideration during cleanup:

- **Tracked Resources** - All resources defined in Terraform state
- **Imported Resources** - Resources created outside Terraform but imported
- **Dependent Resources** - Resources created by APIM but not explicitly defined
- **Backend Storage** - Terraform state storage costs (minimal)

### Billing Impact by SKU

| SKU Tier | Monthly Cost | Cleanup Priority |
|----------|--------------|------------------|
| `Consumption` | Pay-per-call only | Medium |
| `Developer` | ~$50-60/month | **High** |
| `Basic` | ~$150-200/month | **Critical** |
| `Standard` | ~$300-400/month | **Critical** |
| `Premium` | ~$800+/month | **Critical** |

## 🛡️ Safety First

Terraform provides built-in safety mechanisms:

- **Plan Preview** - Shows exactly what will be destroyed
- **Interactive Confirmation** - Requires typing "yes" to proceed
- **State Backup** - Automatic state file backups
- **Dependency Management** - Destroys resources in correct order

## Method 1: Terraform Destroy (Recommended)

The safest and most comprehensive cleanup method for Terraform-managed infrastructure.

### Complete Infrastructure Cleanup

```bash
cd terraform

# Preview what will be destroyed
terraform plan -destroy -var-file="environments/dev.tfvars"

# Destroy all resources
terraform destroy -var-file="environments/dev.tfvars"
```

**Interactive confirmation:**

```bash
Plan: 0 to add, 0 to change, 12 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
```

**What gets destroyed:**
- Azure Resource Group and all contained resources
- API Management service and all APIs
- Application Insights (if created)
- API policies and configurations
- Product and subscription associations
- Diagnostic settings and monitoring

### Environment-Specific Cleanup

```bash
# Development environment
terraform destroy -var-file="environments/dev.tfvars"

# Production environment (use with extreme caution)
terraform destroy -var-file="environments/prod.tfvars"
```

### Auto-Approve (Automation Only)

```bash
# For CI/CD pipelines - USE CAREFULLY
terraform destroy -var-file="environments/dev.tfvars" -auto-approve
```

## Method 2: Selective Resource Destruction

For when you need to remove specific resources while keeping others.

### Target Specific Resources

```bash
# Destroy only the API Management service
terraform destroy -target="azurerm_api_management.apim" -var-file="environments/dev.tfvars"

# Destroy only Application Insights
terraform destroy -target="azurerm_application_insights.apim[0]" -var-file="environments/dev.tfvars"

# Destroy multiple specific resources
terraform destroy \
  -target="azurerm_api_management_api.cars_api" \
  -target="azurerm_api_management_api_policy.cars_api_global[0]" \
  -var-file="environments/dev.tfvars"
```

### Remove from State Only

```bash
# Remove resource from state without destroying it
terraform state rm azurerm_api_management.apim

# List all resources in state
terraform state list

# Show specific resource state
terraform state show azurerm_api_management.apim
```

## Method 3: GitHub Actions Workflow

Use the automated workflow for safe, auditable cleanup.

### Manual Workflow Trigger

1. Go to your GitHub repository
2. Click **Actions** tab
3. Select **Terraform Infrastructure Deployment**
4. Click **Run workflow**
5. Select **destroy** from the action dropdown
6. Confirm execution

### Workflow Cleanup Features

```yaml
# The workflow includes safety checks:
- name: Terraform Destroy
  if: github.event.inputs.action == 'destroy'
  run: |
    terraform destroy -auto-approve -input=false \
      -var="resource_group_name=${{ secrets.APIM_RESOURCE_GROUP }}" \
      -var="apim_service_name=${{ secrets.APIM_SERVICE_NAME }}" \
      # ... other variables
```

**Benefits:**
- **Audit Trail** - All actions logged in GitHub
- **Access Control** - Requires repository permissions
- **Environment Isolation** - Separate workflows per environment
- **Rollback Capability** - Can re-run previous successful deployments

## Method 4: Emergency Cleanup

For when Terraform state is corrupted or unavailable.

### Manual Azure CLI Cleanup

```bash
# Set your resource group name
RG="rg-apim-cars-dev"

# List all resources first
az resource list --resource-group $RG --output table

# Delete entire resource group (use with caution)
az group delete --name $RG --yes --no-wait

# Or delete APIM service only
az apim delete --resource-group $RG --name "your-apim-name" --yes --no-wait
```

### Terraform State Recovery

```bash
# If state is corrupted, try to refresh
terraform refresh -var-file="environments/dev.tfvars"

# Import existing resources back to state
terraform import azurerm_resource_group.apim "/subscriptions/SUB_ID/resourceGroups/RG_NAME"
terraform import azurerm_api_management.apim "/subscriptions/SUB_ID/resourceGroups/RG_NAME/providers/Microsoft.ApiManagement/service/APIM_NAME"
```

## Verification Steps

Always verify cleanup completion to avoid ongoing charges.

### Terraform State Verification

```bash
# Ensure state is clean
terraform show
# Should show: "No state."

# Verify no resources in state
terraform state list
# Should return empty
```

### Azure Resource Verification

```bash
# Check if resource group exists
az group show --name "rg-apim-cars-dev"
# Should return: ResourceGroupNotFound

# List any remaining APIM services
az apim list --output table
# Should not show your deleted service

# Check for any remaining resources
az resource list --resource-group "rg-apim-cars-dev" --output table
# Should return empty or error
```

### Cost Verification

```bash
# Check current month's costs
az consumption usage list --start-date "2024-01-01" --end-date "2024-01-31" \
  --query "[?contains(instanceName, 'apim-cars')]" --output table
```

## Backend Storage Cleanup

Don't forget to clean up Terraform state storage when completely done.

### List State Files

```bash
# List all state files in storage
az storage blob list \
  --container-name tfstate \
  --account-name "yourtfstateaccount" \
  --output table
```

### Delete State Files

```bash
# Delete specific state file
az storage blob delete \
  --container-name tfstate \
  --name "apim-cars-api.tfstate" \
  --account-name "yourtfstateaccount"

# Delete all state files (use with extreme caution)
az storage blob delete-batch \
  --source tfstate \
  --account-name "yourtfstateaccount"
```

### Cleanup State Storage Account

```bash
# When completely done with all Terraform projects
az storage account delete \
  --name "yourtfstateaccount" \
  --resource-group "rg-terraform-state" \
  --yes
```

## Troubleshooting Cleanup Issues

### "Resource has dependents"

Some resources might have dependencies not managed by Terraform:

```bash
# Force delete with dependencies
terraform destroy -var-file="environments/dev.tfvars" -refresh=false

# Or use Azure CLI to force delete
az resource delete --ids $(az resource list --resource-group $RG --query "[].id" -o tsv) --force-deletion-types Microsoft.ApiManagement/service
```

### "State lock detected"

If Terraform state is locked during cleanup:

```bash
# Force unlock (use carefully)
terraform force-unlock LOCK_ID

# Or delete lock manually from backend storage
az storage blob delete \
  --container-name tfstate \
  --name "apim-cars-api.tfstate.lock" \
  --account-name "yourtfstateaccount"
```

### "Provider configuration not found"

If provider configuration is missing:

```bash
# Reinitialize Terraform
terraform init -reconfigure \
  -backend-config="resource_group_name=rg-terraform-state" \
  -backend-config="storage_account_name=yourtfstateXXXXXX" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=apim-cars-api.tfstate"

# Then retry destroy
terraform destroy -var-file="environments/dev.tfvars"
```

### "Cannot destroy resource"

For resources with deletion protection:

```bash
# Check for delete locks
az resource lock list --resource-group $RG --output table

# Remove delete locks
az resource lock delete --name "lock-name" --resource-group $RG

# Retry Terraform destroy
terraform destroy -var-file="environments/dev.tfvars"
```

## Automation and Scheduling

### Scheduled Cleanup

```yaml
# .github/workflows/scheduled-cleanup.yml
name: 'Scheduled Cleanup'
on:
  schedule:
    - cron: '0 2 * * 0'  # Every Sunday at 2 AM
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to cleanup'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging

jobs:
  cleanup:
    name: 'Cleanup Resources'
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3

    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: terraform
      run: terraform init

    - name: Terraform Destroy
      working-directory: terraform
      run: |
        terraform destroy -auto-approve \
          -var-file="environments/${{ github.event.inputs.environment || 'dev' }}.tfvars"
```

### Cost-Based Cleanup

```bash
#!/bin/bash
# cleanup-by-cost.sh - Cleanup resources exceeding cost thresholds

COST_THRESHOLD=10  # $10 USD
RESOURCE_GROUP="rg-apim-cars-dev"

# Get current month costs
CURRENT_COST=$(az consumption usage list \
  --start-date "$(date +%Y-%m-01)" \
  --end-date "$(date +%Y-%m-%d)" \
  --query "[?contains(instanceName, '$RESOURCE_GROUP')] | sum(@.pretaxCost)" \
  --output tsv)

if (( $(echo "$CURRENT_COST > $COST_THRESHOLD" | bc -l) )); then
  echo "Cost $CURRENT_COST exceeds threshold $COST_THRESHOLD"
  echo "Initiating cleanup..."
  
  cd terraform
  terraform destroy -var-file="environments/dev.tfvars" -auto-approve
else
  echo "Cost $CURRENT_COST is within threshold $COST_THRESHOLD"
fi
```

## Best Practices

### Pre-Cleanup Checklist

- [ ] **Backup important data** - Export API definitions, policies
- [ ] **Document configurations** - Save environment variables
- [ ] **Notify team members** - If shared resources
- [ ] **Check dependencies** - Other services using the API
- [ ] **Verify environment** - Ensure you're destroying the right environment

### During Cleanup

- [ ] **Review destroy plan** - Always run `terraform plan -destroy` first
- [ ] **Verify resource list** - Ensure only intended resources will be destroyed
- [ ] **Check for data loss** - Any persistent data that needs backup
- [ ] **Monitor progress** - Watch for any errors during destruction
- [ ] **Keep logs** - Save Terraform output for troubleshooting

### Post-Cleanup

- [ ] **Verify completion** - Check Azure portal and CLI
- [ ] **Monitor costs** - Ensure charges stop appearing
- [ ] **Clean state storage** - Remove unnecessary state files
- [ ] **Update documentation** - Record what was cleaned up
- [ ] **Review next steps** - Plan for future infrastructure needs

## Integration with Existing Makefile

You can still use the existing Makefile commands alongside Terraform:

```bash
# Use Terraform for infrastructure
terraform destroy -var-file="environments/dev.tfvars"

# Use Makefile for API-specific cleanup (if needed)
make clean

# Use Makefile for complete manual cleanup (as backup)
make cleanup-azure
```

## Summary

Terraform cleanup methods ranked by safety and completeness:

1. **`terraform destroy`** - Safest, most complete, recommended
2. **GitHub Actions workflow** - Auditable, controlled, good for teams
3. **Selective destruction** - Precise control, good for partial cleanup
4. **Manual Azure CLI** - Emergency use only, highest risk

**Key Takeaways:**
- Always preview with `terraform plan -destroy` first
- Verify cleanup completion to avoid ongoing charges
- Keep Terraform state backups for recovery
- Use automation for consistent, repeatable cleanup
- Clean up promptly to minimize costs

---

> ⚠️ **Important**: Unlike the Makefile approach, Terraform tracks all resources in state. Always use `terraform destroy` rather than manual deletion to maintain state consistency.