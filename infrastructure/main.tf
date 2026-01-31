terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    # Configure these values via backend config file or -backend-config flags
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "lorotfstate"
    container_name       = "tfstate"
    key                  = "azfunctions.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "australiaeast"
}

variable "app_name" {
  description = "prefix for all resources"
  type        = string
  default     = "loro"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    project     = "Loro"
    managed_by  = "Terraform"
    environment = "dev"
  }
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.app_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Storage Account for Function App
resource "azurerm_storage_account" "storage" {
  name                     = "${replace(var.app_name, "-", "")}${var.environment}st"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags

  depends_on = [azurerm_resource_group.rg]
}

# Application Insights
resource "azurerm_application_insights" "appinsights" {
  name                = "${var.app_name}-${var.environment}-ai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  tags                = var.tags

  depends_on = [azurerm_resource_group.rg]
}

# Service Plan (Flex Consumption)
resource "azurerm_service_plan" "plan" {
  name                = "${var.app_name}-${var.environment}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "FC1"  zone_balancing_enabled = false  tags                = var.tags

  depends_on = [azurerm_resource_group.rg]
}

# Linux Function App (Flex Consumption)
resource "azurerm_linux_function_app" "function_app" {
  name                = "${var.app_name}-${var.environment}-func"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.appinsights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING       = azurerm_application_insights.appinsights.connection_string
    AzureWebJobsStorage                         = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.storage.name};AccountKey=${azurerm_storage_account.storage.primary_access_key};EndpointSuffix=core.windows.net"
    FUNCTIONS_WORKER_RUNTIME                    = "dotnet-isolated"
    FUNCTIONS_EXTENSION_VERSION                 = "~4"
    FUNCTION_APP_EDIT_MODE                      = "readonly"
  }

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    minimum_tls_version = "1.2"
    http2_enabled       = true
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    resource_name = "function_app"
  })

  depends_on = [
    azurerm_service_plan.plan,
    azurerm_storage_account.storage,
    azurerm_application_insights.appinsights
  ]
}

# Outputs
output "function_app_id" {
  value       = azurerm_linux_function_app.function_app.id
  description = "Function App ID"
}

output "function_app_name" {
  value       = azurerm_linux_function_app.function_app.name
  description = "Function App Name"
}

output "function_app_default_hostname" {
  value       = azurerm_linux_function_app.function_app.default_hostname
  description = "Function App Default Hostname"
}

output "function_app_principal_id" {
  value       = azurerm_linux_function_app.function_app.identity[0].principal_id
  description = "Function App Principal ID for RBAC"
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Resource Group Name"
}

output "appinsights_instrumentation_key" {
  value       = azurerm_application_insights.appinsights.instrumentation_key
  sensitive   = true
  description = "Application Insights Instrumentation Key"
}
