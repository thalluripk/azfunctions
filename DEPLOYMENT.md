# Azure Functions Deployment with Terraform & GitHub Actions

This guide explains how to deploy your Azure Functions application using Terraform for infrastructure and GitHub Actions for CI/CD.

## Prerequisites

1. **Azure Subscription** - You need an active Azure subscription
2. **Service Principal** - For GitHub Actions to authenticate with Azure
3. **GitHub Repository** - Your code repository with secrets configured
4. **Local Setup** (optional):
   - Terraform CLI (v1.0+)
   - Azure CLI
   - .NET 8.0 SDK

## Step 1: Create an Azure Service Principal

Run this command in Azure CLI to create a service principal:

```bash
az ad sp create-for-rbac --name "GitHubActionsServicePrincipal" \
  --role "Contributor" \
  --scopes "/subscriptions/{subscription_id}"
```

This will output JSON with credentials needed for GitHub Secrets.

## Step 2: Create Terraform State Storage (Optional but Recommended)

Create a storage account to store Terraform state:

```bash
# Variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="tfstate$(date +%s)"
LOCATION="eastus"
CONTAINER="tfstate"

# Create resource group
az group create -n $RESOURCE_GROUP -l $LOCATION

# Create storage account
az storage account create \
  -n $STORAGE_ACCOUNT \
  -g $RESOURCE_GROUP \
  -l $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

# Create blob container
az storage container create \
  -n $CONTAINER \
  --account-name $STORAGE_ACCOUNT

# Get access key
az storage account keys list -n $STORAGE_ACCOUNT -g $RESOURCE_GROUP
```

Update `infrastructure/backend-config.hcl` with your storage account details.

## Step 3: Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Value |
|---|---|
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `AZURE_TENANT_ID` | From service principal output: `tenant` |
| `AZURE_CLIENT_ID` | From service principal output: `appId` |
| `AZURE_CLIENT_SECRET` | From service principal output: `password` |
| `AZURE_CREDENTIALS` | Full JSON output from service principal creation |
| `TERRAFORM_STATE_ACCESS_KEY` | Storage account access key (from Step 2) |
| `FUNCTION_APP_NAME` | Name of your function app (will be created by Terraform) |
| `FUNCTION_APP_PUBLISH_PROFILE` | Download from Azure Portal after first deployment |
| `FUNCTION_APP_KEY` | Function app master key for testing |

## Step 4: Deploy Infrastructure with Terraform

### Local Development

```bash
cd infrastructure

# Initialize Terraform
terraform init -backend=false  # For local testing
# OR
terraform init -backend-config backend-config.hcl  # For remote state

# Plan deployment
terraform plan -var-file=terraform.tfvars -out=tfplan

# Apply changes
terraform apply tfplan
```

### GitHub Actions Deployment

Simply push to main branch:

```bash
git add .
git commit -m "Deploy Azure Functions"
git push origin main
```

This will:
1. Build your .NET application
2. Run Terraform planning in PR checks
3. Apply Terraform on push to main
4. Deploy the application to Azure Functions
5. Run smoke tests
6. Automatic rollback on failure

## Step 5: Deploy Function App Code

After infrastructure is created, the GitHub workflow automatically:
1. Publishes the .NET application
2. Deploys it using Azure Functions deployment action
3. Runs smoke tests against the deployed endpoint

## Monitoring & Outputs

After deployment, you can access:

- **Function App URL**: `https://<function-app-name>.azurewebsites.net/`
- **Application Insights**: View logs and metrics in Azure Portal
- **Deployment History**: Check GitHub Actions workflow runs

## Terraform Outputs

Get deployment information:

```bash
cd infrastructure
terraform output function_app_default_hostname
terraform output function_app_principal_id
```

## Troubleshooting

### Deployment Failed - "deployment failed: Input string was not in a correct format"

This usually means the application wasn't built correctly. Check:
1. Build logs in GitHub Actions
2. Verify .NET SDK version matches (8.0)
3. Ensure all dependencies are properly restored

### Terraform State Lock

If you get a state lock error:
```bash
terraform force-unlock <LOCK_ID>
```

### Azure Login Failures

Verify your service principal has:
- Correct subscription ID
- Contributor role on the subscription
- Valid credentials in GitHub Secrets

## Environment-Specific Deployments

To deploy to staging/prod, update `terraform.tfvars`:

```hcl
environment = "staging"
location    = "eastus"
```

Then create a new GitHub environment and update the workflow to use it.

## Rollback Procedure

If deployment fails:
1. GitHub Actions automatically initiates rollback
2. Previous version is restored automatically
3. Check GitHub Actions workflow for detailed logs

Manual rollback:
```bash
cd infrastructure
terraform destroy -var-file=terraform.tfvars
```

## Security Best Practices

✅ **Implemented:**
- System-assigned Managed Identity for Function App
- TLS 1.2 minimum
- Application Insights monitoring
- Secure storage of state files
- Service Principal authentication

⚠️ **Recommended Additional Steps:**
- Enable Virtual Network integration
- Configure Private Endpoints
- Set up Azure Policy for compliance
- Enable Azure Defender
- Configure Key Vault for secrets management

## Cost Optimization

Current configuration uses:
- **Flex Consumption (FC1)**: ~$0.20/hour minimum + per-execution cost
- **Standard Storage (LRS)**: ~$0.024/GB/month
- **Application Insights**: Free tier (1GB/day)

For production, consider:
- App Service Plan (reserved instances for predictable workloads)
- Geo-redundant storage if needed
- Optimize retention policies

## Support & References

- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions for Azure](https://github.com/Azure/actions)
- [Azure Functions Best Practices](https://docs.microsoft.com/azure/azure-functions/functions-best-practices)
