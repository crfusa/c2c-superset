param name string
param location string
param appEnvironmentId string
param identityId string
param identityClientId string
param image string
param imageTag string = ''

param revisionMode 'Single' | 'Multiple' = 'Single'

param appPort int = 3000
param external bool

param minScale int = 1
param maxScale int = 3
param scaleCooldownSecs int = 300
param minOpenHoursScale int = minScale

param cpu string = '.25'
param memory string = '.5Gi'

// param livenessCheckPath string = '/alive'
// param startupCheckPath string = '/health'

param openHoursStart string = '0 7 * * 1-5' // 7am, M-F
param openHoursEnd string = '0 19 * * 1-5'  // 7pm, M-F

@export()
type InitContainer = {
  name: string
  args: string[]?
  command: string[]?
  env: {
    name: string
    value: string?
    secretRef: string?
  }[]?
  image: string
  resources: {
    cpu: string
    memory: string
  }
  volumeMounts: {
    mountPath: string
    subPath: string
    volumeName: string
  }[]?
}

param initContainers InitContainer[] = []

@export()
type ScaleRule = {
  name: string
  custom: {
    type: 'azure-servicebus'
    metadata: object
    identity: string?
  }?
}

param scaleRules ScaleRule[] = []
param scaleOnConcurrentHttp int = 10

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
      initContainers: initContainers

      scale: {
        minReplicas: minScale
        maxReplicas: maxScale
        cooldownPeriod: scaleCooldownSecs
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '${scaleOnConcurrentHttp}'
              }
            }
          }
          ...scaleRules
          ...minOpenHoursScale > minScale ? [{
            name: 'cron-scaleup'
            custom: {
              type: 'cron'
              metadata: {
                timezone: 'US/Central'
                start: openHoursStart
                end: openHoursEnd
                desiredReplicas: '${minOpenHoursScale}'
              }
            }
          }] : []
        ]
      }

      containers: [

        // Application
        {
          name: name
          image: imageTag != '' ? '${image}:${imageTag}' : image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          // probes: [
          //   {
          //     type: 'Startup'
          //     failureThreshold: 10
          //     periodSeconds: 10
          //     timeoutSeconds: 5
          //     httpGet: {
          //       port: appPort
          //       path: '${startupCheckPath}?check=startup'
          //     }
          //   }
          //   {
          //     type: 'Readiness'
          //     failureThreshold: 3
          //     initialDelaySeconds: 1
          //     periodSeconds: 10
          //     successThreshold: 1
          //     timeoutSeconds: 5
          //     httpGet: {
          //       port: appPort
          //       path: '${startupCheckPath}?check=readiness'
          //     }
          //   }
          //   {
          //     type: 'Liveness'
          //     failureThreshold: 3
          //     periodSeconds: 5
          //     successThreshold: 1
          //     timeoutSeconds: 1
          //     httpGet: {
          //       port: appPort
          //       path: livenessCheckPath
          //     }
          //   }
          // ]
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

    }
  }
}

output id string = app.id
output hostName string = app.properties.configuration.ingress.fqdn
output outboundIp array = app.properties.outboundIpAddresses
output appName string = app.name
output revisionName string = app.properties.latestRevisionName
