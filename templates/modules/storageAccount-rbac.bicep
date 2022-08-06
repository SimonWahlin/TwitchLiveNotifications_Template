param name string

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param sku string = 'Standard_LRS'

@allowed([
  'Hot'
  'Cool'
  'Premium'
])
param accessTier string = 'Hot'

param blobContainers array = []
param fileShares array = []
param queues array = []
param tables array = []
param tags object = {}
param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: accessTier
    allowSharedKeyAccess: false
  }
  tags: tags
}

resource storageAccountBlobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = if (length(blobContainers) > 0) {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource storageAccountContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = [for containerName in blobContainers: {
  parent: storageAccountBlobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}]

resource storageAccountFileService 'Microsoft.Storage/storageAccounts/fileServices@2021-09-01' = if (length(fileShares) > 0) {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource storageAccountFileShares 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = [for shareName in fileShares: {
  parent: storageAccountFileService
  name: shareName
}]

resource storageAccountQueueService 'Microsoft.Storage/storageAccounts/queueServices@2021-09-01' = if (length(queues) > 0) {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource storageAccountQueues 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-09-01' = [for queueName in queues: {
  parent: storageAccountQueueService
  name: queueName
}]

resource storageAccountTableService 'Microsoft.Storage/storageAccounts/tableServices@2021-09-01' = if (length(tables) > 0) {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource storageAccountTables 'Microsoft.Storage/storageAccounts/tableServices/tables@2021-09-01' = [for tableName in tables: {
  parent: storageAccountTableService
  name: tableName
}]

output id string = storageAccount.id
output name string = storageAccount.name
