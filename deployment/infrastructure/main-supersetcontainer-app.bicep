param name string
param location string
param appEnvironmentId string
param identityId string
param identityClientId string
param image string

param revisionMode 'Single' | 'Multiple' = 'Single'

param appPort int = 3000
param external bool

param cpu string = '.25'
param memory string = '.5Gi'

@description('Array of objects with `name` and `secretRef` or `value`')
param environment {
  name: string
  secretRef: string?
  value: string?
}[] = []

@description('Array of objects with `name` and `keyVaultUrl` or `value`')
param secrets {
  name: string
  keyVaultUrl: string
  identity: string
}[] = []

@description('Array of objects with `serviceId`')
param serviceBindings {
  serviceId: string
}[] = []


param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

param storageShareName string
module share './resource-share.bicep' = {
  name: 'docker-conf'
  params: {
    shareName: 'docker-conf'
    accessMode: 'ReadWrite'
    storageAccountName: storageAccountName
    storageAccountKey: storageAccount.listKeys().keys[0].value
    fileshareName: storageShareName
  }
}

resource app 'Microsoft.App/containerApps@2024-08-02-preview' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }

  properties: {
    managedEnvironmentId: appEnvironmentId
    configuration: {
      registries: [
        {
          identity: identityId
          server: 'c2cshared.azurecr.io'
        }
      ]
      ingress: {
        external: external
        targetPort: appPort
      }
      activeRevisionsMode: revisionMode
      secrets: secrets
    }

    template: {
      serviceBinds: serviceBindings
      terminationGracePeriodSeconds: 180

      #disable-next-line BCP036 // CPU and memory are intentionally strings, since int does not allow fractional values
      initContainers: [
        {
          name: 'superset-init'
          image: image
          command: [
            '/app/docker/docker-init.sh'
          ]
          volumeMounts: [
            {
              mountPath: '/app/docker'
              volumeName: 'docker-conf'
              subPath: 'superset_docker'
            }
            {
              mountPath: '/app/superset_home'
              volumeName: 'docker-conf'
              subPath: 'superset_home'
            }
          ]
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
      ]

      containers: [

        // Application
        {
          name: name
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: [
            { name: 'OTEL_DOTNET_EXPERIMENTAL_OTLP_EMIT_EVENT_LOG_ATTRIBUTES', value: 'true' }
            { name: 'OTEL_DOTNET_EXPERIMENTAL_OTLP_EMIT_EXCEPTION_LOG_ATTRIBUTES', value: 'true' }
            { name: 'OTEL_DOTNET_EXPERIMENTAL_OTLP_RETRY', value: 'in_memory' }
            { name: 'AZURE_CLIENT_ID', value: identityClientId }

            // Add environment parameters
            ...environment
          ]
        }
      ]

      volumes: [
        {
          name: 'docker-conf'
          storageType: 'AzureFile'
          storageName: share.outputs.shareName
        }
      ]
    }
  }
}

output id string = app.id
output hostName string = app.properties.configuration.ingress.fqdn
output outboundIp array = app.properties.outboundIpAddresses
output appName string = app.name
output revisionName string = app.properties.latestRevisionName
