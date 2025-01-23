param env string = resourceGroup().name
param location string = resourceGroup().location
// param imageRegistry string = 'c2cshared.azurecr.io'
// param imageTag string = 'latest'
param isProd bool = true

@secure()
param postgresAdminPassword string = ''

@secure()
param supersetSecret string = ''

@secure()
param microsoftAuthClientSecret string = ''

@secure()
param smtpPasswordSecret string = ''

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

module secretPgAdminPassword './resource-vaultsecret.bicep' = {
  name: 'postgres-adminpassword'
  params: {
    vaultName: keyVault.outputs.vaultName
    secretName: 'PostgresPassword'
    value: postgresAdminPassword
  }
}

module secretSupersetSecret './resource-vaultsecret.bicep' = {
  name: 'superset-secret'
  params: {
    vaultName: keyVault.outputs.vaultName
    secretName: 'SupersetSecret'
    value: supersetSecret
  }
}

module secretMicrosoftAuthClientSecret './resource-vaultsecret.bicep' = {
  name: 'microsoft-auth-client-secret'
  params: {
    vaultName: keyVault.outputs.vaultName
    secretName: 'MicrosoftAuthClientSecret'
    value: microsoftAuthClientSecret
  }
}

module secretSmtpPassword './resource-vaultsecret.bicep' = {
  name: 'smtp-password'
  params: {
    vaultName: keyVault.outputs.vaultName
    secretName: 'SmtpPassword'
    value: smtpPasswordSecret
  }
}

// Azure Storage
module internalStorage './main-internalstorage.bicep' = {
  name: 'internal-storage'
  params: {
    name: storageName(env, 'store')
    location: location
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
    databaseName: 'superset'
    storageSizeGB: isProd ? 128 : 32
    backupRetentionDays: isProd ? 30 : 7
    pgVersion: '15'
    enableQueryDiagnostic: !isProd
    highAvailability: false
    geoRedundantBackup: false
    adminUsername: 'c2cadmin'
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
    allowPublicAccess: true //!isProd
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

// // Build connection strings
// var postgresConnection = 'Host=${db.outputs.hostname};Username=${appIdentity.outputs.name};Database=${db.outputs.appDbName};Ssl Mode=Require'
// var redisConnection = '${cache.outputs.hostname}:${cache.outputs.port},User=${appIdentity.outputs.principalId},ssl=True,abortConnect=False'
// var pgDefaultMaxConnections = 5

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
  dependsOn: [
    roleAssignments
    sharedRoleAssignments
  ]
  params: {
    name: 'app-superset'
    location: location
    appEnvironmentName: appEnvironment.outputs.name
    appEnvironmentId: appEnvironment.outputs.environmentId
    image: 'apache/superset:4.1.1-dev'
    external: true
    identityId: appIdentity.outputs.resourceId
    // identityClientId: appIdentity.outputs.clientId
    storageAccountName: internalStorage.outputs.storageAccountName
    storageShareName: internalStorage.outputs.shareName
    cacheName: cache.outputs.name
    secrets: [
      {
        name: 'pg-password'
        keyVaultUrl: secretPgAdminPassword.outputs.secretUri
        identity: appIdentity.outputs.resourceId
      }
      {
        name: 'superset-secret'
        keyVaultUrl: secretSupersetSecret.outputs.secretUri
        identity: appIdentity.outputs.resourceId
      }
      {
        name: 'mic-auth-client-secret'
        keyVaultUrl: secretMicrosoftAuthClientSecret.outputs.secretUri
        identity: appIdentity.outputs.resourceId
      }
      {
        name: 'smtp-password'
        keyVaultUrl: secretSmtpPassword.outputs.secretUri
        identity: appIdentity.outputs.resourceId
      }
    ]
    environment: [
      // Database
      { name: 'DATABASE_DIALECT', value: 'postgresql' }
      { name: 'DATABASE_USER', value: 'c2cadmin' }
      { name: 'DATABASE_PASSWORD', secretRef: 'pg-password' }
      { name: 'DATABASE_HOST', value: db.outputs.hostname }
      { name: 'DATABASE_PORT', value: '5432' }
      { name: 'DATABASE_DB', value: 'superset' }

      // Redis
      { name: 'REDIS_HOST', value: cache.outputs.hostname  }
      { name: 'REDIS_PORT', value: '${cache.outputs.sslPort}' }
      { name: 'REDIS_PASSWORD', secretRef: 'redis-key' }
      { name: 'REDIS_SSL', value: 'true' }

      // Superset
      { name: 'SUPERSET_SECRET_KEY', secretRef: 'superset-secret' }
      { name: 'PYTHONPATH', value: '/app/docker/pythonpath' }
      { name: 'FLASK_DEBUG', value: 'true' }
      { name: 'SUPERSET_ENV', value: 'production' }
      { name: 'SUPERSET_PORT', value: '8088' }
      { name: 'SUPERSET_CONFIG_PATH', value: '/app/docker/pythonpath/superset_config.py' }

      // Auth
      { name: 'AUTH_TYPE_NAME', value: 'AUTH_OAUTH' }
      { name: 'AUTH_OAUTH_CLIENTID', value: '1da250e9-31d2-4099-9491-38a03a67bdc5' }
      { name: 'AUTH_OAUTH_CLIENTSECRET', secretRef: 'mic-auth-client-secret' }
      { name: 'AUTH_OAUTH_TENANTID', value: 'e04b402a-cd4a-47f5-ab4c-8d132f96d81f' }

      // SMTP
      { name: 'SMTP_PASSWORD', secretRef: 'smtp-password' }

    ]
    // scaleRules: []
    // secrets: []
    // environment: []
  }
}

// Assign App Role(s)
module roleAssignments 'resource-assign-roles.bicep' = {
  name: 'app-apiroles'
  params: {
    roleIds: [
      '4633458b-17de-408a-b874-0445c86b69e6' // Key vault secret user
      // 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    ]
    principalId: appIdentity.outputs.principalId
  }
}

// Assign ACR pull
module sharedRoleAssignments 'resource-assign-roles.bicep' = {
  name: 'app-apisharedroles'
  scope: resourceGroup('f383d19f-1450-426a-bcac-8adc649b71ce', 'c2c-shared')
  params: {
    roleIds: [
      '2efddaa5-3f1f-4df3-97df-af3f13818f4c' // Acr Repo Contributor
      '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
      '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush
      '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage account contributor
    ]
    principalId: appIdentity.outputs.principalId
  }
}
