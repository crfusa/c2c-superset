param name string
param location string = resourceGroup().location
param allowPublicAccess bool

param sku 'Basic' | 'Standard' | 'Premium'
param family 'C' | 'P' = 'C'
param capacity int

param appPrincipalId string
param appPrincipalName string

param vnetId string
param vnetSubnetId string

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: name
  location: location
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: allowPublicAccess ? 'Enabled' : 'Disabled'
    redisConfiguration: {
      'aad-enabled': 'true'
    }
    redisVersion: '6'
    sku: {
      name: sku
      family: family
      capacity: capacity
    }
  }

  resource policyAssignment 'accessPolicyAssignments' = {
    name: 'access-policy-${uniqueString(appPrincipalName)}'
    properties: {
      accessPolicyName: 'Data Contributor'
      objectId: appPrincipalId
      objectIdAlias: appPrincipalName
    }
  }
}

// Create private dns zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = if (!empty(vnetSubnetId)) {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  tags: {}
  properties: {}

  resource networkLink 'virtualNetworkLinks' = {
    name: uniqueString(redisCache.id, vnetId)
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
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
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

output name string = name
output id string = redisCache.id
output hostname string = redisCache.properties.hostName
output port int = redisCache.properties.port
output sslPort int = redisCache.properties.sslPort
output networkInterfaceId string = privateEndpoint.properties.networkInterfaces[0].id
