$Environment = "c2c-shared-superset"
$Subscription = "f383d19f-1450-426a-bcac-8adc649b71ce"

az containerapp logs show --name "app-superset" `
    --resource-group $Environment `
    --subscription $Subscription `
    --container "app-superset" `
    --follow true `
    --format text `
    --type console `
    --tail 100