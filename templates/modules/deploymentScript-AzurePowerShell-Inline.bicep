
param script string
param arguments string = ''
@description('Array of objects with property "name" and either "value" or "secureValue"')
param environmentVariables array = []
@description('ResourceId of user managed identity that should be used to run the script')
param identityResourceId string = ''
@description('Version of Az module to load. See https://mcr.microsoft.com/v2/azuredeploymentscripts-powershell/tags/list for supported versions')
param azPowerShellVersion string = '8.1.0'
@description('Timeout in ISO 8601 pattern (defaults to P20M)')
param timeout string = 'PT1H'
@description('Set a custom name for container group to comply with naming policies')
param containerGroupName string = ''
param tags object = {}
param location string = resourceGroup().location
@description('Will default to current timestamp to use as an update tag, set to static value to prevent re-running same script')
param updateTag string = utcNow()

var containerConfiguration = containerGroupName == '' ? {} : {
  containerSettings: {
    containerGroupName: containerGroupName
  }
}

var identityConfiguration = identityResourceId == '' ? {} : {
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deploymentScript'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
  properties: union(containerConfiguration, identityConfiguration, {
    arguments: arguments
    environmentVariables: environmentVariables
    azPowerShellVersion: azPowerShellVersion
    cleanupPreference: 'Always'
    forceUpdateTag: updateTag
    retentionInterval: 'PT1H'
    scriptContent: script
    timeout: timeout
  })
}

output scriptOutput object = reference(deploymentScript.id).outputs
