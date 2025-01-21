param managedIdentityName string
param location string = resourceGroup().location

// param authPRs bool
// param authBranchName string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location

  // resource masterIdent 'federatedIdentityCredentials' = {
  //   name: 'master'
  //   properties: {
  //     issuer: 'https://token.actions.githubusercontent.com'
  //     subject: 'repo:crfusa/c2c-connect:ref:refs/heads/master'
  //     audiences: [
  //       'api://AzureADTokenExchange'
  //     ]
  //   }
  // }

  // resource branchIdent 'federatedIdentityCredentials' = if (!empty(authBranchName)) {
  //   name: 'branch'
  //   dependsOn: [masterIdent]
  //   properties: {
  //     issuer: 'https://token.actions.githubusercontent.com'
  //     subject: 'repo:crfusa/c2c-connect:environment:${authBranchName}'
  //     audiences: [
  //       'api://AzureADTokenExchange'
  //     ]
  //   }
  // }

  // resource prIdent 'federatedIdentityCredentials' = if (authPRs && !empty(authBranchName)) {
  //   name: 'prs'
  //   dependsOn: [branchIdent]
  //   properties: {
  //     issuer: 'https://token.actions.githubusercontent.com'
  //     subject: 'repo:crfusa/c2c-connect:pull_request'
  //     audiences: [
  //       'api://AzureADTokenExchange'
  //     ]
  //   }
  // }
}

output resourceId string = managedIdentity.id
output clientId string = managedIdentity.properties.clientId
output principalId string = managedIdentity.properties.principalId
output name string = managedIdentityName
