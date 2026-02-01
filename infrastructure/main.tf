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
  name                = "${var.app_name}-${var.environment}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_windows_function_app" "function_app" {
  name                = "${var.app_name}-${var.environment}-func"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  service_plan_id = azurerm_service_plan.plan.id

  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  site_config {
    minimum_tls_version                    = "1.2"
    http2_enabled                          = true
    application_insights_connection_string = azurerm_application_insights.appinsights.connection_string
    application_insights_key               = azurerm_application_insights.appinsights.instrumentation_key
    application_stack {
      dotnet_version              = "v8.0"
      use_dotnet_isolated_runtime = true
    }
  }

}

# API Management Service
resource "azurerm_api_management" "apim" {
  name                = "${var.app_name}-${var.environment}-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Loro API"
  publisher_email     = "admin@loro.local"
  sku_name            = "Consumption_0"

  tags = var.tags
}

# API Management Backend for Function App
resource "azurerm_api_management_backend" "function_backend" {
  name                = "${var.app_name}-function-backend"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = "https://${azurerm_windows_function_app.function_app.default_hostname}"
}

# API Management API
resource "azurerm_api_management_api" "function_api" {
  name                = "${var.app_name}-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Loro Function API"
  path                = "loro"
  protocols           = ["https"]
  description         = "API for Loro HTTP Trigger Function"

  service_url = "https://${azurerm_windows_function_app.function_app.default_hostname}"

  import {
    content_format = "openapi+json"
    content_value = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Loro Function API"
        version = "1.0.0"
      }
      servers = [{
        url = "https://${azurerm_windows_function_app.function_app.default_hostname}"
      }]
      paths = {
        "/api/LoroHttpTrigger" = {
          get = {
            summary     = "Get Loro data"
            operationId = "LoroGet"
            responses = {
              "200" = {
                description = "Success"
              }
            }
            "x-azure-backend" = {
              backend_id = azurerm_api_management_backend.function_backend.name
            }
          }
          post = {
            summary     = "Post Loro data"
            operationId = "LoroPost"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      name  = { type = "string" }
                      email = { type = "string" }
                      age   = { type = "integer" }
                    }
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Success"
              }
            }
            "x-azure-backend" = {
              backend_id = azurerm_api_management_backend.function_backend.name
            }
          }
        }
      }
    })
  }
}

# API Management Operation - GET
resource "azurerm_api_management_api_operation" "get_loro" {
  operation_id        = "get-loro"
  api_name            = azurerm_api_management_api.function_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Get Loro"
  method              = "GET"
  url_template        = "/LoroHttpTrigger"
  description         = "Get request to Loro HTTP Trigger Function"

  response {
    status_code = 200
  }
}

# API Management Operation - POST
resource "azurerm_api_management_api_operation" "post_loro" {
  operation_id        = "post-loro"
  api_name            = azurerm_api_management_api.function_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Post Loro"
  method              = "POST"
  url_template        = "/LoroHttpTrigger"
  description         = "Post request to Loro HTTP Trigger Function"

  request {
    description = "Request body with name, email, age"
  }

  response {
    status_code = 200
  }
}

# API Management API Policy (Function Key Authentication)
resource "azurerm_api_management_api_policy" "function_api_policy" {
  api_name            = azurerm_api_management_api.function_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service base-url="https://${azurerm_windows_function_app.function_app.default_hostname}" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# Outputs
output "function_app_id" {
  value       = azurerm_windows_function_app.function_app.id
  description = "Function App ID"
}

output "function_app_name" {
  value       = azurerm_windows_function_app.function_app.name
  description = "Function App Name"
}

output "function_app_default_hostname" {
  value       = azurerm_windows_function_app.function_app.default_hostname
  description = "Function App Default Hostname"
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

output "apim_gateway_url" {
  value       = azurerm_api_management.apim.gateway_url
  description = "API Management Gateway URL"
}

output "apim_name" {
  value       = azurerm_api_management.apim.name
  description = "API Management Instance Name"
}

output "apim_api_endpoint" {
  value       = "${azurerm_api_management.apim.gateway_url}/${azurerm_api_management_api.function_api.path}"
  description = "API Management API Endpoint"
}
