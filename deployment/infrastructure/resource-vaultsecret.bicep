param vaultName string
param secretName string
@secure()
param value string

// Whether to set the secret or not
var setSecret = !empty(value)

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: vaultName

  resource secret 'secrets' = if (setSecret) {
    name: secretName
    properties: {
      value: value
    }
  }

  resource secretExisting 'secrets' existing = if (!setSecret) {
    name: secretName
  }
}

output vaultName string = vaultName

output secretUri string = setSecret
  ? keyVault::secret.properties.secretUri
  : keyVault::secretExisting.properties.secretUri

output secretName string = secretName
