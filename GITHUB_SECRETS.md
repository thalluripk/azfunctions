# GitHub Secrets Configuration Checklist

## Required Secrets for Deployment

Complete these steps to set up GitHub Secrets for the deployment workflow.

### Step 1: Create Azure Service Principal

Run this command in Azure CLI:
```bash
az ad sp create-for-rbac --name "GitHubActionsServicePrincipal" \
  --role "Contributor" \
  --scopes "/subscriptions/{your-subscription-id}"
```

Save the output JSON - you'll need values from it.

### Step 2: Add GitHub Secrets

Go to your GitHub repository:
1. **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add each secret with the values below:

#### Azure Authentication Secrets

| Secret Name | Value | Example |
|---|---|---|
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | `tenantId` from service principal output | `87654321-4321-4321-4321-210987654321` |
| `AZURE_CLIENT_ID` | `appId` from service principal output | `11111111-1111-1111-1111-111111111111` |
| `AZURE_CLIENT_SECRET` | `password` from service principal output | (Keep this secret!) |
| `AZURE_CREDENTIALS` | Full JSON from service principal creation | `{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}` |

#### Terraform State Storage

| Secret Name | Value |
|---|---|
| `TERRAFORM_STATE_ACCESS_KEY` | Storage account access key (from `az storage account keys list`) |

#### Function App Deployment

| Secret Name | Value | Notes |
|---|---|---|
| `FUNCTION_APP_NAME` | Name of your function app | Will be created by Terraform as `func-loro-{environment}` |
| `FUNCTION_APP_PUBLISH_PROFILE` | Download from Azure Portal after first deployment | **Azure Portal** → Function App → **Get Publish Profile** |
| `FUNCTION_APP_KEY` | Function app master key | **Azure Portal** → Function App → **App Keys** or **Host Keys** |

## Step 3: Create Terraform State Storage (Optional but Recommended)

```bash
#!/bin/bash
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="tfstate$(date +%s | tail -c 9)"
LOCATION="eastus"

# Create resources
az group create -n $RESOURCE_GROUP -l $LOCATION
az storage account create -n $STORAGE_ACCOUNT -g $RESOURCE_GROUP -l $LOCATION --sku Standard_LRS
az storage container create -n tfstate --account-name $STORAGE_ACCOUNT

# Get access key
az storage account keys list -n $STORAGE_ACCOUNT -g $RESOURCE_GROUP --query '[0].value' -o tsv
```

Update `infrastructure/backend-config.hcl`:
```hcl
resource_group_name  = "rg-terraform-state"
storage_account_name = "tfstate1234567890"
container_name       = "tfstate"
key                  = "azfunctions/terraform.tfstate"
```

## Step 4: Get Function App Credentials After First Deployment

After Terraform creates the infrastructure:

1. Go to **Azure Portal**
2. Find your Function App (search for `func-loro-dev`)
3. **Get Publish Profile**: 
   - Click the "Get publish profile" button at the top
   - Save as `FUNCTION_APP_PUBLISH_PROFILE` secret
4. **Get Function Keys**:
   - Navigate to **Functions** → **LoroHttpTrigger** → **Function Keys**
   - Copy the default key or create new one
   - Save as `FUNCTION_APP_KEY` secret

## Verification

Once all secrets are added:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Verify all 9 secrets are listed:
   - ✅ AZURE_SUBSCRIPTION_ID
   - ✅ AZURE_TENANT_ID
   - ✅ AZURE_CLIENT_ID
   - ✅ AZURE_CLIENT_SECRET
   - ✅ AZURE_CREDENTIALS
   - ✅ TERRAFORM_STATE_ACCESS_KEY
   - ✅ FUNCTION_APP_NAME
   - ✅ FUNCTION_APP_PUBLISH_PROFILE
   - ✅ FUNCTION_APP_KEY

## Automated Setup

You can also run the automated setup script:

**On Linux/macOS:**
```bash
chmod +x setup-deployment.sh
./setup-deployment.sh
```

**On Windows:**
```cmd
setup-deployment.cmd
```

These scripts will:
- Check prerequisites
- Guide you through service principal creation
- Create Terraform state storage
- Display all values needed for GitHub Secrets

## Security Notes

⚠️ **Important:**
- Never commit secrets or credentials to Git
- Secrets starting with `${{ secrets. }}` are automatically masked in logs
- Regularly rotate credentials
- Use GitHub's secret rotation features
- Restrict secret access to necessary workflows only

## Troubleshooting

### Secret not found in workflow
- Ensure secret name matches exactly (case-sensitive)
- Verify secret exists in repository settings
- Check that the workflow file uses correct syntax: `${{ secrets.SECRET_NAME }}`

### Authentication fails
- Verify all 5 Azure secrets are correct
- Check service principal still has Contributor role
- Ensure subscription ID is correct

### Can't get Function App credentials
- Wait 5 minutes after Terraform deployment completes
- Function App must be fully deployed before publishing profile is available
- Check that Function App name in GitHub matches actual deployed name

## Next Steps

1. ✅ Add all secrets
2. ✅ Commit `.github/workflows/deploy.yml`
3. ✅ Commit `infrastructure/` folder
4. ✅ Push to GitHub
5. Watch the workflow run automatically!
