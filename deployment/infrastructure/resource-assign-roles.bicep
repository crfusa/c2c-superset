param principalId string
param roleIds array
param princpalType string = 'ServicePrincipal'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for roleId in roleIds: {
  name: guid(resourceGroup().id, roleId, principalId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: principalId
    principalType: princpalType
  }
}]
