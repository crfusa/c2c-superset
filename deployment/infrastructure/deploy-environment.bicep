targetScope = 'subscription'

param location string = deployment().location
param environment string
param imageTag string = 'latest'
param isProd bool = true

@secure()
param postgresAdminPassword string = ''

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
    imageTag: imageTag
    location: location

    postgresAdminPassword: postgresAdminPassword
  }
}
