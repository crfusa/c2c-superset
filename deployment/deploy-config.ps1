#!/usr/bin/env pwsh
param (
    [string] $Subscription = "f383d19f-1450-426a-bcac-8adc649b71ce",
    [string] $AccountName = "c2csharedsupersetstore",
    [string] $ShareName = "configuration-c2csharedsupersets"
)

# Get storage account key
$keys = az storage account keys list `
    --subscription $subscription `
    --account-name $AccountName | ConvertFrom-Json

$key = $keys[0].value

Write-Host "Uploading server to Azure File Share"
# Push-Location ..
try {
    az storage file upload-batch `
        --subscription $subscription `
        --account-name $AccountName `
        --account-key $key `
        --source "./docker" `
        --destination $ShareName `
        --destination-path "superset_docker"
}
finally {
    # Pop-Location
}