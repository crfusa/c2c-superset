param name string
param location string
param appEnvironmentId string
param appEnvironmentName string
param identityId string
// param identityClientId string
param image string

param revisionMode 'Single' | 'Multiple' = 'Single'

param appPort int = 8088
param external bool

param cpu string = '.25'
param memory string = '.5Gi'

param initializeSuperset bool = false

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
    appEnvironmentName: appEnvironmentName
    shareName: 'docker-conf'
    accessMode: 'ReadWrite'
    storageAccountName: storageAccountName
    storageAccountKey: storageAccount.listKeys().keys[0].value
    fileshareName: storageShareName
  }
}

param cacheName string
resource cacheRef 'Microsoft.Cache/redis@2023-08-01' existing = {
  name: cacheName
}

resource app 'Microsoft.App/containerApps@2024-10-02-preview' = {
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
        customDomains: [
          {
            name: 'superset.crfusa.com'
            bindingType: 'Auto'
          }
        ]
      }
      activeRevisionsMode: revisionMode
      secrets: [
        ...secrets
        {
          name: 'redis-key'
          value: cacheRef.listKeys().primaryKey
        }
      ]
    }

    template: {
      serviceBinds: serviceBindings
      terminationGracePeriodSeconds: 180

      scale: {
        minReplicas: 1
      }

      initContainers: initializeSuperset ? [
        {
          name: 'init-superset'
          image: image
          command: [
            '/app/docker/docker-init.sh'
          ]
          env: [
            ...environment
          ]
          volumeMounts: [
            {
              mountPath: '/app/docker'
              volumeName: 'docker-conf'
              subPath: 'superset_docker'
            }
            {
              mountPath: '/app/superset_home'
              volumeName: 'superset-home'
            }
          ]
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
      ] : []

      containers: [

        // Application
        {
          name: name
          image: image
          command: [
            '/app/docker/docker-bootstrap.sh'
            'app-gunicorn'
          ]
          env: [
            ...environment
          ]
          volumeMounts: [
            {
              mountPath: '/app/docker'
              volumeName: 'docker-conf'
              subPath: 'superset_docker'
            }
            {
              mountPath: '/app/superset/static/assets/custom'
              volumeName: 'docker-conf'
              subPath: 'superset_static'
            }
            {
              mountPath: '/app/superset_home'
              volumeName: 'superset-home'
            }
          ]
          resources: {
            cpu: json(cpu)
            memory: memory
          }
        }

        // Worker
        {
          name: '${name}-worker'
          image: image
          command: [
            '/app/docker/docker-bootstrap.sh'
            'worker'
          ]
          env: [
            ...environment
          ]
          volumeMounts: [
            {
              mountPath: '/app/docker'
              volumeName: 'docker-conf'
              subPath: 'superset_docker'
            }
            {
              mountPath: '/app/superset_home'
              volumeName: 'superset-home'
            }
          ]
          resources: {
            cpu: json('0.75')
            memory: '1.5Gi'
          }
        }

        // Beat
        {
          name: '${name}-beat'
          image: image
          command: [
            '/app/docker/docker-bootstrap.sh'
            'beat'
          ]
          env: [
            ...environment
          ]
          volumeMounts: [
            {
              mountPath: '/app/docker'
              volumeName: 'docker-conf'
              subPath: 'superset_docker'
            }
            {
              mountPath: '/app/superset_home'
              volumeName: 'superset-home'
            }
          ]
          resources: {
            cpu: json(cpu)
            memory: memory
          }
        }
      ]

      volumes: [
        {
          name: 'docker-conf'
          storageType: 'AzureFile'
          storageName: share.outputs.shareName
        }
        {
          name: 'superset-home'
          storageType: 'EmptyDir'
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
