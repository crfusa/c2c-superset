param name string
param location string = resourceGroup().location
param allowSharedKeyAuth bool = false
param vnetSubnets string[] = []

@allowed([
  'Standard_LRS'
  'Standard_RAGRS'
])
param sku string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: name
  location: location
  kind: 'StorageV2'
  sku: { name: sku }
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: allowSharedKeyAuth
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      ipRules: []
      defaultAction: length(vnetSubnets) > 0 ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      virtualNetworkRules: [for vnet in vnetSubnets: {
        action: 'Allow'
        #disable-next-line use-resource-id-functions
        id: vnet
      }]
    }
  }

  resource fileshares 'fileServices' = {
    name: 'default'

    // FileShares
    resource configuration 'shares' = {
      name: take('configuration-${name}', 32)
    }
  }

}

// Outputs
// output tableEndpoint string = storageAccount.properties.primaryEndpoints.table
// output queueEndpoint string = storageAccount.properties.primaryEndpoints.queue
// output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output fileEndpoint string = storageAccount.properties.primaryEndpoints.file
output storageAccountName string = name
output shareName string = storageAccount::fileshares::configuration.name
