#!/usr/bin/env pwsh
param (
    [String] $AcrName = "c2cshared",
    [string] $Subscription = "f383d19f-1450-426a-bcac-8adc649b71ce",
    [switch] $BuildImages
)

if ($BuildImages) {
    # Deploy superset images
    Push-Location ..
    try {
        docker compose -f docker-compose-non-dev.yml build
    }
    finally {
        Pop-Location
    }
}

$AcrPath = "$AcrName.azurecr.io"

az acr login -n $AcrName --subscription $Subscription

# Tag the `superset-superset` image as $AcrPath/c2c-superset/superset
docker tag superset-superset $AcrPath/c2c-superset/superset

docker push $AcrPath/c2c-superset/superset