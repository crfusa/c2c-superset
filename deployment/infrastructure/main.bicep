param env string = resourceGroup().name
param location string = resourceGroup().location
param imageRegistry string = 'c2cshared.azurecr.io'
param imageTag string = 'latest'
param isProd bool = true

@secure()
param postgresAdminPassword string = ''

var resourceToken = uniqueString(resourceGroup().id)

// Helper function to generate a storage account name
func storageName(env string, name string) string => take('${replace(env, '-','')}${name}', 24)

// Import tags
module tags './resource-tags.bicep' = {
  name: 'tags'
  params: {
    env: env
    isProduction: isProd
    location: location
    utility: 'Environment'
  }
}

// Virtual Network
module vnet './main-vnet.bicep' = {
  name: 'vnet'
  params: {
    vaultName: 'vnet-${resourceToken}'
    location: location
  }
}

// Managed Identity
module appIdentity './resource-identity.bicep' = {
  name: 'app-identity'
  params: {
    managedIdentityName: 'supersetident-${resourceToken}'
    // authBranchName: isProd ? 'master' : envShort
    // authPRs: envShort == 'qa'
    location: location
  }
}

// Key Vault
module keyVault './resource-keyvault.bicep' = {
  name: 'key-vault'
  params: {
    vaultName: 'vault-${resourceToken}'
    location: location
    enableForTemplateDeployment: true
    enablePurgeProtection: isProd ? true : null
    vnetSubnets: [
      vnet.outputs.appSubnetId
    ]
  }
}

// Copy shared secrets
resource keyVaultRef 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: 'vault-${resourceToken}'
  dependsOn: [ keyVault ]
}

module pgAdminPassword './resource-vaultsecret.bicep' = {
  name: 'postgres-adminpassword'
  params: {
    vaultName: keyVault.outputs.vaultName
    secretName: 'PostgresPassword'
    value: postgresAdminPassword
  }
}

// Azure Storage
module internalStorage './main-internalstorage.bicep' = {
  name: 'internal-storage'
  params: {
    name: storageName(env, 'store')
    location: location
    sku: isProd ? 'Standard_RAGRS' : 'Standard_LRS'
    allowSharedKeyAuth: true
    vnetSubnets: [
      vnet.outputs.appSubnetId
    ]
  }
}

// Postgres Database
module db './main-postgres.bicep' = {
  name: 'db'
  dependsOn: [ keyVaultRef ]
  params: {
    name: '${env}-postgres'
    sku:'Standard_B1ms'
    tier: 'Burstable'
    databaseName: 'connect'
    storageSizeGB: isProd ? 128 : 32
    backupRetentionDays: isProd ? 30 : 7
    pgVersion: '15'
    enableQueryDiagnostic: !isProd
    highAvailability: false
    geoRedundantBackup: false
    adminUsername: 'c2cadmin'
    // adminPassword: postgresAdminPassword
    adminPassword: !empty(postgresAdminPassword)
      ? postgresAdminPassword
      : keyVaultRef.getSecret('PostgresPassword')
    appPrincipalId: appIdentity.outputs.principalId
    appPrincipalName: appIdentity.outputs.name
    vnetId: vnet.outputs.vnetId
    vnetSubnetId: vnet.outputs.dbSubnetId
  }
}

// Redis Cache
module cache './main-redis.bicep' = {
  name: 'cache'
  params: {
    name: '${env}-redis'
    location: location
    sku: 'Basic'
    capacity: 0
    family: 'C'
    allowPublicAccess: !isProd
    appPrincipalId: appIdentity.outputs.principalId
    appPrincipalName: appIdentity.outputs.name
    vnetId: vnet.outputs.vnetId
    vnetSubnetId: vnet.outputs.cacheSubnetId
  }
}

// Application Insights Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'workspace-${resourceToken}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Build connection strings
var postgresConnection = 'Host=${db.outputs.hostname};Username=${appIdentity.outputs.name};Database=${db.outputs.appDbName};Ssl Mode=Require'
var redisConnection = '${cache.outputs.hostname}:${cache.outputs.port},User=${appIdentity.outputs.principalId},ssl=True,abortConnect=False'
var pgDefaultMaxConnections = 5

func pgConnection(postgresConnection string, maxPoolSize int) string =>
  '${postgresConnection};Maximum Pool Size=${maxPoolSize}'

// Container App Environment
module appEnvironment './main-appenvironment.bicep' = {
  name: 'app-environment'
  params: {
    name: '${env}-env1'
    location: location
    insightsWorkspaceName: logAnalyticsWorkspace.name
    infrastructureSubnetId: vnet.outputs.appSubnetId
    zoneRedundant: isProd
  }
}

module appSuperset './main-supersetcontainer-app.bicep' = {
  name: 'app-superset'
  params: {
    name: 'app-superset'
    location: location
    appEnvironmentId: appEnvironment.outputs.environmentId
    image: '${imageRegistry}/c2c-superset/superset:${imageTag}'
    external: true
    identityId: appIdentity.outputs.resourceId
    identityClientId: appIdentity.outputs.clientId
    storageAccountName: internalStorage.outputs.storageAccountName
    storageShareName: internalStorage.outputs.shareName
    // scaleRules: []
    // secrets: []
    // environment: []
  }
}
