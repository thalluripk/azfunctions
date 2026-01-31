# Backend configuration for Terraform state
# Replace these values with your actual Azure storage account details
# 
# Usage: terraform init -backend-config=backend-config.hcl
#
resource_group_name  = "rg-terraform-state"
storage_account_name = "lorotfstate"
container_name       = "tfstate"
key                  = "azfunctions.tfstate"
