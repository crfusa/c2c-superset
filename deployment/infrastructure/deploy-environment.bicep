targetScope = 'subscription'

param location string = deployment().location
param environment string
param isProd bool = true

@secure()
param postgresAdminPassword string = ''

@secure()
param supersetSecret string = ''

@secure()
param microsoftAuthClientSecret string = ''

@secure()
param smtpPasswordSecret string = ''

@secure()
param mapboxKey string = ''

resource resourceGroup 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: environment
  location: location
}

module main 'main.bicep' = {
  name: 'bicep-deploy'
  scope: resourceGroup
  params: {
    env: environment
    isProd: isProd
    location: location

    postgresAdminPassword: postgresAdminPassword
    supersetSecret: supersetSecret
    microsoftAuthClientSecret: microsoftAuthClientSecret
    smtpPasswordSecret: smtpPasswordSecret
    mapboxKey: mapboxKey
  }
}
