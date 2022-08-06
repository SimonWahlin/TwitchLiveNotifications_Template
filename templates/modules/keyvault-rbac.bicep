param name string

@description('ResourceId of storage account where audit logs will be sent')
param diagnosticsStorageResourceId string = ''
@description('Number of days to keep audit logs in storage, use 0 for unlimited')
param diagnosticsStorageRetention int = 0

@description('ResourceId of log analytics workspace where audit logs will be sent')
param diagnosticsLogAnalyticsResourceId string = ''
@description('Number of days to keep audit logs in log analytics, use 0 for unlimited')
param diagnosticsLogAnalyticsWorkspaceRetention int = 90

@description('Soft delete makes deleted Key Vault and secrets recoverable for 90 days.')
param enableSoftDelete bool = false

param tags object = {}
param location string = resourceGroup().location

resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: name
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: enableSoftDelete
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
  tags: tags
}

resource keyvaultDiagStorage 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticsStorageResourceId != '') {
  scope: keyvault
  name: 'service'
  properties: {
    storageAccountId: diagnosticsStorageResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: diagnosticsStorageRetention != 0
          days: diagnosticsStorageRetention
        }
      }
    ]
  }
}

resource keyvaultDiagLogAnalytics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticsLogAnalyticsResourceId != '') {
  scope: keyvault
  name: 'logAnalyticsAudit'
  properties: {
    workspaceId: diagnosticsLogAnalyticsResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: diagnosticsLogAnalyticsWorkspaceRetention != 0
          days: diagnosticsLogAnalyticsWorkspaceRetention
        }
      }
    ]
  }
}

output name string = keyvault.name
output id string = keyvault.id
output vaultUri string = keyvault.properties.vaultUri
