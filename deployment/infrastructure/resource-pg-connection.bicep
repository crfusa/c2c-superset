param name string
param location string = resourceGroup().location
param vnetId string
param vnetSubnetId string
param postgresServerId string

// Create private dns zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: {}
  properties: {}

  resource networkLink 'virtualNetworkLinks' = {
    name: uniqueString(postgresServerId, vnetId)
    location: 'global'
    properties: {
      virtualNetwork: {
        id: vnetId
      }
      registrationEnabled: false
    }
  }
}

// Create private endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${name}-pe'
  location: location
  properties: {
    subnet: {
      id: vnetSubnetId
    }
    customNetworkInterfaceName: '${name}-nic'
    privateLinkServiceConnections: [
      {
        name: '${name}-pe'
        properties: {
          privateLinkServiceId: postgresServerId
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }

  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: privateDnsZone.name
          properties: {
            privateDnsZoneId: privateDnsZone.id
          }
        }
      ]
    }
  }
}

output networkInterfaceId string = privateEndpoint.properties.networkInterfaces[0].id
