param name string
param location string = resourceGroup().location
param insightsWorkspaceName string
param infrastructureSubnetId string
param zoneRedundant bool = false
param enablemTLS bool = false
param enableAspireDashboard bool = false

@secure()
param appInsightsConnectionString string = ''

// Get insights workspace
resource insightsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: insightsWorkspaceName
}

// Create Environment-specific Container App Environment
#disable-next-line BCP081
resource environment 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: name
  location: location
  properties: {
    peerAuthentication: {
      mtls: {
        enabled: enablemTLS
      }
    }
    appInsightsConfiguration: appInsightsConnectionString != '' ? {
      connectionString: appInsightsConnectionString
    } : {}
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: insightsWorkspace.properties.customerId
        #disable-next-line use-secure-value-for-secure-inputs
        sharedKey: insightsWorkspace.listKeys().primarySharedKey
      }
    }
    openTelemetryConfiguration: appInsightsConnectionString != '' ? {
      tracesConfiguration: {
        destinations: [
          'appInsights'
        ]
      }
      logsConfiguration: {
        destinations: [
          'appInsights'
        ]
      }
    } : {}
    vnetConfiguration: infrastructureSubnetId != '' ? {
      internal: false
      infrastructureSubnetId: infrastructureSubnetId
    } : null
    zoneRedundant: zoneRedundant

    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }

  #disable-next-line BCP081
  resource aspireDashboard 'dotNetComponents' = if (enableAspireDashboard) {
    name: 'aspiredashboard'
    properties: {
      componentType: 'AspireDashboard'
    }
  }
}

output name string = environment.name
output environmentId string = environment.id
