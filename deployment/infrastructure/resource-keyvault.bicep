param vaultName string 
param location string = resourceGroup().location
param enableForTemplateDeployment bool = false
param enableDataProtection bool = false
param enablePurgeProtection true | null
param vnetSubnets array = []

// Use RBAC:
// https://docs.microsoft.com/en-us/azure/key-vault/general/rbac-guide?tabs=azure-cli

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForTemplateDeployment: enableForTemplateDeployment
    enabledForDiskEncryption: false
    enablePurgeProtection: enablePurgeProtection
    enableSoftDelete: true
    enableRbacAuthorization: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      ipRules: []
      defaultAction: length(vnetSubnets) > 0 ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      virtualNetworkRules: [for vnet in vnetSubnets: {
        ignoreMissingVnetServiceEndpoint: false
        id: vnet
      }]
    }
  }

  /* *** Keys *** */
  resource dataProtectionKey 'keys' = if (enableDataProtection) {
    name: 'dataprotection'
    properties: {
      kty: 'RSA'
      keySize: 2048
    }
  }
}

output vaultName string = keyVault.name
output vaultId string = keyVault.id
output vaultUri string = keyVault.properties.vaultUri
