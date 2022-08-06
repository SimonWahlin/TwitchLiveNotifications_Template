@minLength(1)
@maxLength(40)
param name string

@allowed([
  'Windows'
  'Linux'
])
param operatingSystem string = 'Linux'
param zoneRedundant bool = false
param tags object = {}
param location string = resourceGroup().location

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Y1'
  }
  properties: {
    reserved: operatingSystem == 'Linux'
    zoneRedundant: zoneRedundant
  }
  tags: tags
}

output id string = hostingPlan.id
