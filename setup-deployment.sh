#!/bin/bash

# Azure Functions - Setup Script for Local Development
# This script helps set up your local environment for Terraform deployment

set -e

echo "=== Azure Functions Deployment Setup ==="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform v1.0+"
    echo "   Visit: https://www.terraform.io/downloads"
    exit 1
fi
echo "✅ Terraform found: $(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)"

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install Azure CLI"
    echo "   Visit: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi
echo "✅ Azure CLI found: $(az --version | head -1)"

if ! command -v dotnet &> /dev/null; then
    echo "❌ .NET SDK not found. Please install .NET 8.0"
    echo "   Visit: https://dotnet.microsoft.com/download"
    exit 1
fi
echo "✅ .NET SDK found: $(dotnet --version)"

echo ""
echo "=== Service Principal Setup ==="
echo ""

# Check if already logged in
if az account show &> /dev/null; then
    CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    echo "✅ Currently logged into Azure"
    echo "   Subscription: $SUBSCRIPTION_NAME"
    echo "   ID: $CURRENT_SUBSCRIPTION"
else
    echo "Please log in to Azure:"
    az login
fi

echo ""
read -p "Enter a name for the Service Principal (default: GitHubActionsServicePrincipal): " SP_NAME
SP_NAME=${SP_NAME:-GitHubActionsServicePrincipal}

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo ""
echo "Creating Service Principal: $SP_NAME"
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role "Contributor" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --json-auth)

echo ""
echo "✅ Service Principal created!"
echo ""
echo "=== GitHub Secrets to Configure ==="
echo ""
echo "Copy these values to GitHub Settings → Secrets and variables → Actions:"
echo ""
echo "AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
echo "AZURE_TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenantId')"
echo "AZURE_CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.clientId')"
echo "AZURE_CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r '.clientSecret')"
echo ""
echo "AZURE_CREDENTIALS='$SP_OUTPUT'"
echo ""

echo "=== Optional: Terraform State Storage Setup ==="
echo ""
read -p "Do you want to create Terraform state storage? (y/n, default: n): " CREATE_STATE
if [[ "$CREATE_STATE" == "y" ]]; then
    RESOURCE_GROUP="rg-terraform-state"
    STORAGE_ACCOUNT="tfstate$(date +%s | tail -c 9)"
    LOCATION="eastus"
    CONTAINER="tfstate"

    echo "Creating Resource Group: $RESOURCE_GROUP"
    az group create -n $RESOURCE_GROUP -l $LOCATION

    echo "Creating Storage Account: $STORAGE_ACCOUNT"
    az storage account create \
        -n $STORAGE_ACCOUNT \
        -g $RESOURCE_GROUP \
        -l $LOCATION \
        --sku Standard_LRS \
        --kind StorageV2 \
        --enable-hierarchical-namespace false

    echo "Creating Blob Container: $CONTAINER"
    az storage container create \
        -n $CONTAINER \
        --account-name $STORAGE_ACCOUNT

    ACCESS_KEY=$(az storage account keys list -n $STORAGE_ACCOUNT -g $RESOURCE_GROUP --query '[0].value' -o tsv)

    echo ""
    echo "✅ Terraform state storage created!"
    echo ""
    echo "Add this to infrastructure/backend-config.hcl:"
    echo ""
    echo "resource_group_name  = \"$RESOURCE_GROUP\""
    echo "storage_account_name = \"$STORAGE_ACCOUNT\""
    echo "container_name       = \"$CONTAINER\""
    echo "key                  = \"azfunctions/terraform.tfstate\""
    echo ""
    echo "Add this GitHub Secret:"
    echo "TERRAFORM_STATE_ACCESS_KEY=$ACCESS_KEY"
    echo ""
fi

echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Add the GitHub Secrets from above to your repository"
echo "2. Update infrastructure/backend-config.hcl with your state storage details"
echo "3. Commit and push your changes"
echo "4. The GitHub workflow will automatically deploy on push to main"
echo ""
echo "For more information, see DEPLOYMENT.md"
