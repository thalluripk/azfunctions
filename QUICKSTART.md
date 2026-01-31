# Quick Start Checklist

Complete these steps in order to deploy your Azure Functions with Terraform and GitHub Actions.

## ✅ Phase 1: Prerequisites (5 minutes)

- [ ] Have Azure Subscription ID ready
- [ ] Have GitHub repository with code pushed
- [ ] Have Azure CLI installed locally (optional, for setup script)
- [ ] Have Terraform CLI installed locally (optional, for local testing)

## ✅ Phase 2: Azure Service Principal (5 minutes)

Run this command in Azure CLI:
```bash
az ad sp create-for-rbac --name "GitHubActionsServicePrincipal" \
  --role "Contributor" \
  --scopes "/subscriptions/{your-subscription-id}"
```

**Save the output JSON** - you'll need these values:
- `clientId` → AZURE_CLIENT_ID
- `clientSecret` → AZURE_CLIENT_SECRET
- `subscriptionId` → AZURE_SUBSCRIPTION_ID
- `tenantId` → AZURE_TENANT_ID

## ✅ Phase 3: Terraform State Storage (10 minutes)

Optional but recommended for production.

### Using Setup Script (Automated)
```bash
# Linux/macOS
chmod +x setup-deployment.sh
./setup-deployment.sh

# Windows
setup-deployment.cmd
```

### Manual Setup
```bash
az group create -n rg-terraform-state -l eastus
az storage account create -n tfstate$RANDOM -g rg-terraform-state -l eastus --sku Standard_LRS
az storage container create -n tfstate --account-name tfstate$RANDOM
az storage account keys list -n tfstate$RANDOM -g rg-terraform-state
```

Update `infrastructure/backend-config.hcl` with your values.

## ✅ Phase 4: GitHub Secrets (5 minutes)

Go to your GitHub repository:
**Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 9 secrets:

| # | Secret Name | Value |
|---|---|---|
| 1 | `AZURE_SUBSCRIPTION_ID` | Your subscription ID |
| 2 | `AZURE_TENANT_ID` | tenantId from service principal |
| 3 | `AZURE_CLIENT_ID` | clientId from service principal |
| 4 | `AZURE_CLIENT_SECRET` | clientSecret from service principal |
| 5 | `AZURE_CREDENTIALS` | Full JSON output |
| 6 | `TERRAFORM_STATE_ACCESS_KEY` | Storage account key (if using state storage) |
| 7 | `FUNCTION_APP_NAME` | `func-loro-dev` (or your app name) |
| 8 | `FUNCTION_APP_PUBLISH_PROFILE` | Download after first deployment |
| 9 | `FUNCTION_APP_KEY` | Function app key (get after first deployment) |

**Note:** Secrets 8 & 9 can be added after first deployment completes.

## ✅ Phase 5: Configure Terraform (5 minutes)

Update `infrastructure/terraform.tfvars` (if needed):
```hcl
environment = "dev"              # or "staging", "prod"
location    = "eastus"           # Your Azure region
app_name    = "loro"             # Application name
```

## ✅ Phase 6: Deploy! (5 minutes)

```bash
# Commit your changes
git add .
git commit -m "Deploy Azure Functions with Terraform and GitHub Actions"
git push origin main
```

**That's it!** GitHub Actions will automatically:
1. ✅ Build your .NET application
2. ✅ Run Terraform plan checks
3. ✅ Deploy infrastructure with Terraform
4. ✅ Deploy your function app
5. ✅ Run smoke tests

Monitor the deployment:
1. Go to **Actions** tab in your GitHub repository
2. Click the workflow run
3. Watch the deployment progress

## ✅ Phase 7: Verify Deployment (5 minutes)

### In GitHub
- [ ] Workflow completed successfully (green checkmark)
- [ ] All jobs passed (build, terraform-plan, deploy)

### In Azure Portal
- [ ] Resource group created: `rg-loro-dev`
- [ ] Function App created: `func-loro-dev`
- [ ] Storage account created
- [ ] Application Insights created

### Test Your Function
```bash
# Get your function app URL
FUNCTION_URL="https://func-loro-dev.azurewebsites.net/api/LoroHttpTrigger"

# Test with curl
curl -X POST "$FUNCTION_URL?code=YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"test","email":"test@example.com","age":30}'
```

You should get a JSON response.

## 🎯 Common Next Steps

### Add More Environments
1. Create `terraform.tfvars.staging`
2. Update workflow for environment selection
3. Deploy to staging branch

### Add Custom Domain
1. Create Azure App Service Domain or CNAME
2. Add to Function App in Azure Portal
3. Update DNS records

### Enable Virtual Network Integration
1. Edit `infrastructure/main.tf`
2. Add subnet configuration
3. Add VNET integration block
4. Run `terraform apply`

### Add Authentication
1. Update `LoroHttpTrigger.cs` authorization level
2. Change from `AuthorizationLevel.Function` to `AuthorizationLevel.Admin`
3. Rebuild and redeploy

## ❌ Troubleshooting

### Workflow fails: "Secret not found"
- Check secret names in GitHub match workflow (case-sensitive)
- Verify all required secrets are added

### Terraform fails: "Authentication failed"
- Verify Azure CLI credentials
- Check service principal has Contributor role
- Ensure subscription ID is correct

### Deployment fails: "Function App creation failed"
- Check Azure subscription has capacity
- Ensure resource group doesn't already exist with conflicts
- Check Azure Portal for error details

### Can't connect to Function App
- Wait 2-3 minutes after deployment completes
- Function App needs time to start
- Check Application Insights logs in Azure Portal

## 📚 Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Full deployment guide
- [CONFIGURATION.md](CONFIGURATION.md) - Detailed configuration reference
- [GITHUB_SECRETS.md](GITHUB_SECRETS.md) - GitHub secrets reference
- [Terraform Documentation](https://www.terraform.io/docs)
- [Azure Functions Documentation](https://learn.microsoft.com/azure/azure-functions/)

## ⏱️ Time Estimate

- Phase 1-2: 10 minutes
- Phase 3: 10 minutes (optional)
- Phase 4-6: 10 minutes
- Phase 7: 5 minutes

**Total: ~35 minutes to full deployment** ✅

---

**Success!** Your Azure Functions are now deployed with Terraform and GitHub Actions CI/CD. 🎉

Any changes you push to main branch will automatically be deployed!
