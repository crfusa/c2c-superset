$Environment = "c2c-superset"
$Subscription = "f383d19f-1450-426a-bcac-8adc649b71ce"

$dateDeployed = Get-Date

$null = az containerapp update `
    -n "app-superset" `
    -g $Environment `
    --subscription $Subscription `
    --container-name "app-superset" `
    --set-env-vars `
        "DateDeployed=$dateDeployed"