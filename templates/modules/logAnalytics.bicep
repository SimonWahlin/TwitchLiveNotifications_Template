param name string
param tags object = {}
param location string = resourceGroup().location

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
  }
  tags: tags
}

output id string = logAnalytics.id
