@echo off
REM Azure Functions - Setup Script for Local Development (Windows)
REM This script helps set up your local environment for Terraform deployment

echo.
echo === Azure Functions Deployment Setup ===
echo.

REM Check prerequisites
echo Checking prerequisites...

where terraform >nul 2>nul
if %errorlevel% neq 0 (
    echo X Terraform not found. Please install Terraform v1.0+
    echo   Visit: https://www.terraform.io/downloads
    exit /b 1
)
for /f "tokens=*" %%i in ('terraform version -json 2^>nul ^| findstr "terraform_version" ^| cut -d^^^: -f2 ^| cut -d^^^" -f2') do set TERRAFORM_VERSION=%%i
echo. Terraform found
if defined TERRAFORM_VERSION (
    echo   Version: %TERRAFORM_VERSION%
)

where az >nul 2>nul
if %errorlevel% neq 0 (
    echo X Azure CLI not found. Please install Azure CLI
    echo   Visit: https://docs.microsoft.com/cli/azure/install-azure-cli
    exit /b 1
)
echo. Azure CLI found

where dotnet >nul 2>nul
if %errorlevel% neq 0 (
    echo X .NET SDK not found. Please install .NET 8.0
    echo   Visit: https://dotnet.microsoft.com/download
    exit /b 1
)
for /f "tokens=*" %%i in ('dotnet --version 2^>nul') do set DOTNET_VERSION=%%i
echo. .NET SDK found: %DOTNET_VERSION%

echo.
echo === Service Principal Setup ===
echo.

REM Check if logged in
az account show >nul 2>nul
if %errorlevel% equ 0 (
    echo. Already logged into Azure
    for /f "tokens=*" %%i in ('az account show --query id -o tsv') do set CURRENT_SUBSCRIPTION=%%i
    for /f "tokens=*" %%i in ('az account show --query name -o tsv') do set SUBSCRIPTION_NAME=%%i
    echo   Subscription: %SUBSCRIPTION_NAME%
    echo   ID: %CURRENT_SUBSCRIPTION%
) else (
    echo Please log in to Azure:
    call az login
)

echo.
set /p SP_NAME="Enter a name for the Service Principal (default: GitHubActionsServicePrincipal): "
if "%SP_NAME%"=="" set SP_NAME=GitHubActionsServicePrincipal

for /f "tokens=*" %%i in ('az account show --query id -o tsv') do set SUBSCRIPTION_ID=%%i

echo.
echo Creating Service Principal: %SP_NAME%
REM Note: This part is complex in batch; you may need to run the az command manually

echo.
echo === Next Steps ===
echo.
echo Run this command to create the Service Principal and capture credentials:
echo.
echo az ad sp create-for-rbac ^
echo   --name "%SP_NAME%" ^
echo   --role "Contributor" ^
echo   --scopes "/subscriptions/%SUBSCRIPTION_ID%" ^
echo   --json-auth
echo.
echo Copy the output to your GitHub Secrets (Settings ^> Secrets and variables ^> Actions):
echo - AZURE_SUBSCRIPTION_ID: %SUBSCRIPTION_ID%
echo - AZURE_TENANT_ID: tenantId from output
echo - AZURE_CLIENT_ID: appId from output
echo - AZURE_CLIENT_SECRET: password from output
echo - AZURE_CREDENTIALS: entire JSON output
echo.
echo For more information, see DEPLOYMENT.md
