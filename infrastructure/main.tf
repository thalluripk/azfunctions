terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.102.0" # Force a minimum of 3.102
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
  subscription_id = "fba18915-b6c5-401f-86a6-9fb245012d60"
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

resource "azurerm_storage_container" "container" {
  name                  = "funcblobcontainer"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "azurerm_log_analytics_workspace" "example" {
  name                = "${var.app_name}-${var.environment}-la"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Application Insights
resource "azurerm_application_insights" "appinsights" {
  name                = "${var.app_name}-${var.environment}-ai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  tags                = var.tags
  workspace_id        = azurerm_log_analytics_workspace.example.id

  depends_on = [azurerm_resource_group.rg]
}

# Service Plan (Flex Consumption)
resource "azurerm_service_plan" "plan" {
  name                   = "${var.app_name}-${var.environment}-plan"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  os_type                = "Linux"
  sku_name               = "FC1"
  zone_balancing_enabled = false
  tags                   = var.tags

  depends_on = [azurerm_resource_group.rg]
}

# Linux Function App (Flex Consumption)
resource "azurerm_function_app_flex_consumption" "function_app" {
  name                = "${var.app_name}-${var.environment}-func"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.container.name}"
  storage_authentication_type = "SystemAssignedIdentity"
  runtime_name                = "dotnet-isolated"
  runtime_version             = "8.0"
  maximum_instance_count      = 50
  instance_memory_in_mb       = 2048

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.appinsights.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.appinsights.connection_string
    AzureWebJobsStorage                   = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.storage.name};AccountKey=${azurerm_storage_account.storage.primary_access_key};EndpointSuffix=core.windows.net"
    FUNCTIONS_EXTENSION_VERSION           = "~4"
    FUNCTION_APP_EDIT_MODE                = "readonly"
  }

  site_config {
    minimum_tls_version = "1.2"
    http2_enabled       = true
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    resource_name = "function_app"
  })


}

# Outputs
output "function_app_id" {
  value       = azurerm_function_app_flex_consumption.function_app.id
  description = "Function App ID"
}

output "function_app_name" {
  value       = azurerm_function_app_flex_consumption.function_app.name
  description = "Function App Name"
}

output "function_app_default_hostname" {
  value       = azurerm_function_app_flex_consumption.function_app.default_hostname
  description = "Function App Default Hostname"
}

output "function_app_principal_id" {
  value       = azurerm_function_app_flex_consumption.function_app.identity[0].principal_id
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
