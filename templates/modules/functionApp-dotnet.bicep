param functionAppName string
param hostingPlanId string
param logAnalyticsWorkspaceId string = ''
@description('Days to keep logs in log analytics workspace. Set to 0 for indefinite.')
param logAnalyticsRetentionDays int = 90
param netFrameworkVersion string = '6.0'
param dailyMemoryTimeQuota int = 1000000
param appInsightsId string = ''
param tags object = {}
param location string = resourceGroup().location

var appInsightsTag = appInsightsId == '' ? {} : {
  'hidden-link: /app-insights-resource-id': appInsightsId
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    httpsOnly: true
    dailyMemoryTimeQuota: dailyMemoryTimeQuota
    serverFarmId: hostingPlanId
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: netFrameworkVersion
      scmType: 'None'
    }
    containerSize: 1536 // not used any more, but portal complains without it
  }
  tags: union(tags, appInsightsTag)
}

resource functionAppDiagLogAnalytics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(logAnalyticsWorkspaceId != '') {
  scope: functionApp
  name: 'logAnalyticsAudit'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: logAnalyticsRetentionDays > 0
          days: logAnalyticsRetentionDays
        }
      }
    ]
  }
}

output name string = functionApp.name
output id string = functionApp.id
output defaultHostName string = functionApp.properties.defaultHostName
output principalTenantId string = functionApp.identity.tenantId
output principalId string = functionApp.identity.principalId
