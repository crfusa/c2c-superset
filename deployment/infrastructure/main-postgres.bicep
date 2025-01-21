param location string = resourceGroup().location
param name string
param databaseName string = 'postgres'
param pgVersion string = '16'

param enableQueryDiagnostic bool

param sku 'Standard_B1ms' | 'Standard_E2ds_v5'
param tier 'GeneralPurpose' | 'Burstable' | 'MemoryOptimized'
param storageSizeGB int

param backupRetentionDays int
param geoRedundantBackup bool
param highAvailability bool

param vnetId string
param vnetSubnetId string

param extensions string = 'citext,postgis'

param appPrincipalId string
param appPrincipalName string

@secure()
param adminPassword string
param adminUsername string

var diagnosticUserOverrides = enableQueryDiagnostic ? [
  { name: 'pg_qs.query_capture_mode', value: 'ALL' }
  { name: 'pgms_wait_sampling.query_capture_mode', value: 'ALL' }
  { name: 'track_io_timing', value: 'ON' }
] : []

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: name
  location: location
  sku: {
    name: sku
    tier: tier
  }
  properties: {
    version: pgVersion
    administratorLogin: empty(adminPassword) ? null : adminUsername
    administratorLoginPassword: empty(adminPassword) ? null : adminPassword
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    highAvailability: {
      mode: highAvailability ? 'Enabled' : 'Disabled'
      standbyAvailabilityZone: highAvailability ? '2' : null
    }
    availabilityZone: '1'
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
  }

  resource db 'databases' = if (databaseName != 'postgres') {
    name: databaseName
  }

  resource config 'configurations' = if (extensions != '') {
    name: 'azure.extensions'
    dependsOn: databaseName != 'postgres' ? [
      db
    ] : []
    properties: {
      value: extensions
      source: 'user-override'
    }
  }

  resource adminAssignnment 'administrators' = {
    name: appPrincipalId
    dependsOn: [
      config
    ]
    properties: {
      tenantId: subscription().tenantId
      principalType: 'ServicePrincipal'
      principalName: appPrincipalName
    }
  }

  @batchSize(1)
  resource diagnosticConfigurations 'configurations' = [for override in diagnosticUserOverrides: {
    name: override.name
    dependsOn: [
      adminAssignnment
    ]
    properties: {
      value: override.value
      source: 'user-override'
    }
  }]
}

// Create private dns zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = if (!empty(vnetSubnetId)) {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: {}
  properties: {}

  resource networkLink 'virtualNetworkLinks' = {
    name: uniqueString(postgresServer.id, vnetId)
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
          privateLinkServiceId: postgresServer.id
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

output id string = postgresServer.id
output hostname string = postgresServer.properties.fullyQualifiedDomainName
output connectionString string = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};'
output appDbName string = databaseName
output networkInterfaceId string = privateEndpoint.properties.networkInterfaces[0].id
