param keyVaultName string

@description('GUID representing the id of a role definition')
param roleDefinitionId string

@description('PrincipalId of identity that will be granted the role')
param principalId string

@description('PrincipalType of identity that will be granted the role')
@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string = 'User'

resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: roleDefinitionId
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: keyvault
  name: guid(keyvault.id, principalId, roleDefinition.id)
  properties: {
    roleDefinitionId: roleDefinition.id
    principalId: principalId
    principalType: principalType
  }
}
