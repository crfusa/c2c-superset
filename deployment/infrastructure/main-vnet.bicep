param location string = resourceGroup().location
param vaultName string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vaultName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      // App subnet
      {
        name: 'apps'
        properties: {
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          addressPrefix: '10.1.13.0/26'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                '*'
              ]
            }
            {
              service: 'Microsoft.KeyVault'
              locations: [
                '*'
              ]
            }
            {
              service: 'Microsoft.AzureCosmosDB'
              locations: [
                '*'
              ]
            }
          ]
        }
      }

      // Database subnet
      {
        name: 'postgres'
        properties: {
          addressPrefix: '10.1.14.0/26'
        }
      }

      // Cache subnet
      {
        name: 'redis'
        properties: {
          addressPrefix: '10.1.15.0/26'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }

  resource apps 'subnets' existing = {
    name: 'apps'
  }

  resource postgres 'subnets' existing = {
    name: 'postgres'
  }

  resource redis 'subnets' existing = {
    name: 'redis'
  }
}

output vnetId string = vnet.id
output appSubnetId string = vnet::apps.id
output dbSubnetId string = vnet::postgres.id
output cacheSubnetId string = vnet::redis.id
