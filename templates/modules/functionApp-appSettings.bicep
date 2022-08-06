param functionAppName string
param customAppSettings object
param webJobsStorageAccountName string
param functionKeysKeyVaultUri string

param packageUri string = ''

@allowed([
  'dotnet'
  'dotnet-isolated'
  'java'
  'node'
  'powershell'
  'python'
])
param workerRuntime string = 'dotnet-isolated'

@description('Number of processes running our function on each instance')
@minValue(1)
@maxValue(10)
param workerProcessCount int = 3

@description('ResourceId for application insights integration, leave empty to disable')
param appInsightsResourceId string = ''

resource functionApp 'Microsoft.Web/sites@2021-03-01' existing = {
  name: functionAppName
}

var appInsightsSettings = appInsightsResourceId == '' ? {} : {
  APPLICATIONINSIGHTS_CONNECTION_STRING: reference(appInsightsResourceId, '2020-02-02').ConnectionString
}

resource functionAppSettings 'Microsoft.Web/sites/config@2020-06-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: union(customAppSettings, appInsightsSettings, {
    AzureWebJobsDisableHomepage: 'true'
    AzureWebJobsSecretStorageKeyVaultUri: functionKeysKeyVaultUri
    AzureWebJobsSecretStorageType: 'keyvault'
    AzureWebJobsStorage__accountName: webJobsStorageAccountName
    FUNCTIONS_APP_EDIT_MODE: 'readonly'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_PROCESS_COUNT: workerProcessCount
    FUNCTIONS_WORKER_RUNTIME: workerRuntime
    WEBSITE_RUN_FROM_PACKAGE: packageUri == '' ? '1' : packageUri
    WEBSITE_MOUNT_ENABLED: '1'
  })
}
