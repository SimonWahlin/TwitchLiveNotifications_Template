param name string
param linkedResourceId string
param logAnalyticsId string
param tags object = {}
param location string = resourceGroup().location

resource appInsights 'Microsoft.insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  tags: union(tags,{
    'hidden-link:${linkedResourceId}': 'Resource'
  })
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsId
  }
}

output id string = appInsights.id
