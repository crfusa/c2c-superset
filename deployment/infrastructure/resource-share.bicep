param appEnvironmentName string
param storageAccountName string
param shareName string
param fileshareName string
param accessMode 'ReadOnly' | 'ReadWrite' = 'ReadWrite'

@secure()
param storageAccountKey string

resource appEnvironment 'Microsoft.App/managedEnvironments@2022-10-01' existing = {
  name: appEnvironmentName

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
