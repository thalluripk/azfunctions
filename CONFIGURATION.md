# Deployment Configuration Guide

## Project Structure

```
AzFunctions/
├── .github/
│   └── workflows/
│       └── deploy.yml              # GitHub Actions CI/CD workflow
├── infrastructure/
│   ├── main.tf                     # Terraform main configuration
│   ├── terraform.tfvars            # Terraform variables
│   ├── backend-config.hcl          # Terraform backend configuration
│   └── .gitignore                  # Terraform-specific gitignore
├── DEPLOYMENT.md                   # Deployment guide (this file)
├── GITHUB_SECRETS.md              # GitHub secrets configuration
├── setup-deployment.sh             # Automated setup script (Linux/macOS)
├── setup-deployment.cmd            # Automated setup script (Windows)
├── LoroHttpTrigger.cs             # Function handler
├── Program.cs                      # Function app configuration
├── local.settings.json             # Local development settings
└── AzFunctions.csproj             # Project file

```

## Configuration Files Reference

### infrastructure/main.tf
Defines all Azure resources:
- **Resource Group**: Containers for all resources
- **Storage Account**: Required for Function App runtime
- **Application Insights**: Monitoring and logging
- **Service Plan (Flex Consumption)**: Billing model for Functions
- **Linux Function App**: The actual Azure Functions resource
- **Managed Identity**: For secure RBAC

**Key Variables:**
```hcl
environment = "dev"              # Environment name (dev, staging, prod)
location    = "eastus"           # Azure region
app_name    = "loro"             # Application name
tags        = {...}              # Resource tags
```

### infrastructure/terraform.tfvars
Provides values for variables in main.tf.

**To customize:**
- Change `environment` for staging/prod deployments
- Update `location` to your preferred Azure region
- Modify `tags` for your organization

### infrastructure/backend-config.hcl
Terraform remote state configuration.

**Before first deployment, fill in:**
```hcl
resource_group_name  = "your-resource-group"
storage_account_name = "yourstorageaccount"
container_name       = "tfstate"
key                  = "azfunctions/terraform.tfstate"
```

Run: `terraform init -backend-config backend-config.hcl`

### .github/workflows/deploy.yml
Automated deployment pipeline with 4 jobs:

| Job | Trigger | Purpose |
|---|---|---|
| `build` | Always | Build .NET application and publish |
| `terraform-plan` | Pull Requests | Show infrastructure changes |
| `deploy` | Push to main | Deploy infrastructure and app |
| `rollback` | Deploy fails | Automatic rollback on failure |

**Workflow Flow:**
```
Push/PR
  ├─→ Build Job (always)
  │    ├─ Restore dependencies
  │    ├─ Build Release
  │    └─ Publish to artifact
  │
  ├─→ Terraform Plan (PR only)
  │    ├─ Format check
  │    ├─ Validate
  │    └─ Plan changes
  │
  └─→ Deploy Job (push to main only)
       ├─ Terraform Apply
       ├─ Deploy Function App
       ├─ Run Smoke Tests
       └─ Notify Success
```

## Environment Variables in Workflow

The workflow uses these environment variables (defined in the YAML):

```yaml
DOTNET_VERSION: '8.0'              # .NET SDK version
ARTIFACT_NAME: 'function-app'      # Build artifact name
TERRAFORM_VERSION: '1.6.0'         # Terraform version
```

Update these if needed for different versions.

## Deployment Environments

### Development (Default)
- Environment: `dev`
- Location: `eastus`
- Billing: Flex Consumption (FC1)
- Monitoring: Application Insights (Free tier)

To deploy to development, push to main branch.

### Staging
Create `terraform.tfvars.staging`:
```hcl
environment = "staging"
location    = "eastus"
```

Create GitHub environment and update workflow:
```yaml
environment:
  name: staging
```

Run: `terraform apply -var-file=terraform.tfvars.staging`

### Production
Create `terraform.tfvars.prod`:
```hcl
environment = "prod"
location    = "eastus"
```

Add manual approval in workflow:
```yaml
environment:
  name: production
```

## Local Development

### Initialize Terraform (without remote state)
```bash
cd infrastructure
terraform init -backend=false
```

### Plan changes locally
```bash
terraform plan -var-file=terraform.tfvars -out=tfplan
```

### Apply locally
```bash
terraform apply tfplan
```

### Destroy infrastructure
```bash
terraform destroy -var-file=terraform.tfvars
```

## CI/CD Pipeline Details

### Build Stage
1. Checkout code
2. Setup .NET 8.0
3. Restore NuGet packages
4. Build Release configuration
5. Publish to directory
6. Upload artifact to GitHub

**Time:** ~5-10 minutes

### Plan Stage (PRs only)
1. Checkout code
2. Setup Terraform
3. Validate Terraform format
4. Initialize Terraform
5. Validate configuration
6. Plan infrastructure changes
7. Comment on PR with plan

**Time:** ~2-3 minutes

### Deploy Stage (main branch only)
1. Download published artifact
2. Initialize Terraform with remote state
3. Plan changes
4. Apply changes automatically
5. Deploy to Function App
6. Run HTTP smoke test
7. Notify on success/failure

**Time:** ~10-15 minutes

### Rollback Stage (on failure)
- Automatic rollback initiated
- Previous deployment restored
- Status posted to PR/commit

## Variables and Customization

### Changing Function Name
Edit `infrastructure/terraform.tfvars`:
```hcl
app_name = "mynewapp"
```

Result: Function App named `func-mynewapp-dev`

### Changing Azure Region
```hcl
location = "westus2"
```

Available regions: `eastus`, `westus2`, `centralus`, `westeurope`, `eastasia`, etc.

### Adding Tags
```hcl
tags = {
  project     = "MyProject"
  managed_by  = "Terraform"
  environment = "dev"
  owner       = "DevOps"
  costcenter  = "12345"
}
```

### Scaling Configuration
Edit `main.tf` in `site_config`:
```hcl
function_app_scale_limit = 100          # Max instances
runtime_scale_monitoring_enabled = true # Auto-scale
```

## Monitoring Deployments

### GitHub Actions
1. Go to repository
2. **Actions** tab
3. Click workflow run
4. Expand job to see logs

### Azure Portal
1. Search for your Resource Group: `rg-loro-dev`
2. View resources created
3. Click Function App to see deployment
4. **Monitor** → **Logs** for Application Insights

### Terraform
```bash
cd infrastructure
terraform state list          # View all resources
terraform state show <resource>  # Details on specific resource
terraform output              # View outputs
```

## Costs

Monthly estimate (dev environment):

| Resource | SKU | Cost |
|---|---|---|
| Service Plan | Flex Consumption (FC1) | $0.20/hour (~$150/month minimum) |
| Storage | Standard LRS | $1-5/month |
| App Insights | Free tier | $0 (1GB/day limit) |
| **Total** | | **~$155/month** |

## Next Steps

1. ✅ Add all GitHub Secrets (see GITHUB_SECRETS.md)
2. ✅ Update `infrastructure/backend-config.hcl`
3. ✅ Commit all files
4. ✅ Push to main branch
5. ✅ Watch GitHub Actions deploy automatically

## Support

- Terraform Azure Provider Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest
- Azure Functions: https://learn.microsoft.com/azure/azure-functions/
- GitHub Actions: https://docs.github.com/en/actions
- Terraform State: https://www.terraform.io/language/state
