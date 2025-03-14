#!/usr/bin/env pwsh
param (
    [string] $Environment = "c2c-superset",
    [string] $Subscription = "f383d19f-1450-426a-bcac-8adc649b71ce",
    [string] $ImageTag = "latest",
    [switch] $PromptForSecrets
)

$root = $PSScriptRoot

$parameters = @(
    "--parameters", "environment=$Environment"
)

# Prompt to enter secrets
if ($PromptForSecrets) {
    $ErrorActionPreference = 'SilentlyContinue'

    # Prompt for Postgres Admin Password
    $PostgresAdminPasswordSecret = Read-Host -Prompt "Postgres Admin Password" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    if ($PostgresAdminPasswordSecret) { $parameters += "--parameters", "postgresAdminPassword=$PostgresAdminPasswordSecret" }

    # Prompt for Superset Secret
    $SupersetSecret = Read-Host -Prompt "Superset Secret" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    if ($SupersetSecret) { $parameters += "--parameters", "supersetSecret=$SupersetSecret" }

    # Prompt for Microsoft Auth client secrete
    $MicrosoftAuthClientSecret = Read-Host -Prompt "Microsoft Auth Client Secret" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    if ($MicrosoftAuthClientSecret) { $parameters += "--parameters", "microsoftAuthClientSecret=$MicrosoftAuthClientSecret" }

    # Prompt for SMTP password
    $SMTPPassword = Read-Host -Prompt "SMTP Password" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    if ($SMTPPassword) { $parameters += "--parameters", "smtpPasswordSecret=$SMTPPassword" }

    # Prompt for MapBox key
    $MapBoxKey = Read-Host -Prompt "MapBox Key" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    if ($MapBoxKey) { $parameters += "--parameters", "mapboxKey=$MapBoxKey" }

    $ErrorActionPreference = 'Continue'
}

# Deploy deploy-environment
$null = az deployment sub create `
    -n "deploy-$Environment" `
    --template-file $root/infrastructure/deploy-environment.bicep `
    --subscription $Subscription `
    --location centralus `
    $parameters `
    | ConvertFrom-Json
