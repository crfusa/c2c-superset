#disable-next-line no-unused-params
param location string = resourceGroup().location
param utility string = 'LocalEnvironment'
param isProduction bool = false

param env string = resourceGroup().name

// Add tags
resource tags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  properties: {
    tags: {
      Application: 'Superset'
      Utility: utility
      Environment: env
      Production: '${isProduction}'
    }
  }
}
