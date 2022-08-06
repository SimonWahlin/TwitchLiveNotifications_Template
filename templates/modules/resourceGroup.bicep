targetScope = 'subscription'

param resourceGroupName string
@description('Region where resources will be deployed')
param location string = 'westeurope'

param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output id string = resourceGroup.id
output name string = resourceGroup.name
