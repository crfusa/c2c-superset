param storageAccountName string
param shareName string
param fileshareName string
param accessMode 'ReadOnly' | 'ReadWrite' = 'ReadOnly'

@secure()
param storageAccountKey string

resource appEnvironment 'Microsoft.App/managedEnvironments@2022-10-01' existing = {
  name: 'cms-environment'

  resource share 'storages' = {
    name: shareName
    properties: {
      azureFile: {
        accessMode: accessMode
        accountKey: storageAccountKey
        accountName: storageAccountName
        shareName: fileshareName
      }
    }
  }
}

output shareName string = appEnvironment::share.name
