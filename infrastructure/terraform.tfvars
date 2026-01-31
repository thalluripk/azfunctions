# Terraform variables for AzFunctions deployment
environment = "dev"
location    = "australiaeast"
app_name    = "loro"

tags = {
  project     = "Loro"
  managed_by  = "Terraform"
  environment = "dev"
  owner       = "DevOps"
}
