targetScope = 'subscription'

@description('Globally unique name for function app.')
param functionAppName string
param functionAppResourceGroupName string
@description('SubscriptionId where all function resources will be created, leave empty to use current subscription.')
param functionAppSubscriptionId string = subscription().subscriptionId

@description('Version of TwitchLiveNotification to deploy, use full tag name like v1.0.1')
param version string = 'latest'

@description('Name of key vault used to store secrets like access tokens to Twitch, Twitter and Discord.')
param keyVaultName string
param keyVaultResourceGroupName string
@description('SubscriptionId where key vault will be created, leave empty to use current subscription.')
param keyVaultSubscriptionId string = subscription().subscriptionId

param discordTemplateOnFollow string
param discordTemplateOnStreamOnline string
param twitterTemplateOnFollow string
param twitterTemplateOnStreamOnline string

@secure()
param discordWebhookUri string
@secure()
param twitchClientId string
@secure()
param twitchClientSecret string
@secure()
param twitchSignatureSecret string
@secure()
param twitterConsumerKey string
@secure()
param twitterConsumerSecret string
@secure()
param twitterAccessToken string
@secure()
param twitterAccessTokenSecret string

@description('Storage account SKU')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param storageAccountSku string = 'Standard_LRS'

@description('PrincipalId of identity that will be granted access to deploy code and manage secrets')
param adminPrincipalId string = ''

@description('PrincipalType of identity that will be granted access to deploy code')
@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param adminPrincipalType string = 'User'

@description('Quota of GB-seconds that can be used each day.')
param dailyMemoryTimeQuota int = 60000

@description('Region where resources will be deployed')
param location string = 'westeurope'

param tags object = {}

var hostingPlanName = '${functionAppName}-plan'
var logAnalyticsName = '${functionAppName}-log'
var applicationInsightsName = '${functionAppName}-appin'
var functionAppNameNoDash = replace(functionAppName, '-', '')
var uniqueStringRg = uniqueString(resourceId('Microsoft.Resources/resourceGroups', functionAppResourceGroupName))
var storageAccountName = toLower('${take(functionAppNameNoDash, 17)}${take(uniqueStringRg, 5)}sa')
var functionAppKeyVaultName = '${take(functionAppNameNoDash, 17)}${take(uniqueStringRg, 5)}kv'

var packageName = 'TwitchLiveNotifications.zip'
var deployContainerName = 'deploy'
var packageUri = 'https://${storageAccountName}.blob.${environment().suffixes.storage}/${deployContainerName}/${packageName}'

var roleStorageAccountContributor = '17d1049b-9a84-46fb-8f53-869881c3d3ab'
var roleStorageBlobDataOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var roleStorageTableDataContributor = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var roleStorageQueueDataContributor = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var roleKeyVaultSecretsOfficer = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var roleKeyVaultSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'

var functionKeySecretName = 'functionAccessKey'

var secretsList = [
  {
    name: 'DiscordWebhookUri'
    value: discordWebhookUri 
  }
  {
    name: 'TwitchClientId'
    value: twitchClientId 
  }
  {
    name: 'TwitchClientSecret'
    value: twitchClientSecret 
  }
  {
    name: 'TwitchSignatureSecret'
    value: twitchSignatureSecret 
  }
  {
    name: 'TwitterConsumerKey'
    value: twitterConsumerKey 
  }
  {
    name: 'TwitterConsumerSecret'
    value: twitterConsumerSecret 
  }
  {
    name: 'TwitterAccessToken'
    value: twitterAccessToken 
  }
  {
    name: 'TwitterAccessTokenSecret'
    value: twitterAccessTokenSecret 
  }
]

module functionAppResourceGroupDeploy 'modules/resourceGroup.bicep' = {
  scope: subscription(functionAppSubscriptionId)
  name: functionAppResourceGroupName
  params: {
    resourceGroupName: functionAppResourceGroupName
    tags: tags
    location: location
  }
}

resource functionAppResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription(functionAppSubscriptionId)
  name: functionAppResourceGroupName
}

module storageAccount 'modules/storageAccount-rbac.bicep' = {
  scope: functionAppResourceGroup
  name: storageAccountName
  params: {
    name: storageAccountName
    blobContainers: [
      'deploy'
    ]
    queues: [
      'addsubscription'
      'removesubscription'
      'discordmessage'
      'onfollowevent'
      'onstreamonlineevent'
      'onstreamofflineevent'
      'twittertweet'
    ]
    tables: [
      'TwichLiveNotificationsConfiguration'
    ]
    sku: storageAccountSku
    tags: tags
    location: location
  }
  dependsOn:[
    functionAppResourceGroupDeploy
  ]
}
module logAnalytics 'modules/logAnalytics.bicep' = {
  scope: functionAppResourceGroup
  name: logAnalyticsName
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
  dependsOn:[
    functionAppResourceGroupDeploy
  ]
}
module appInsights 'modules/appInsights.bicep' = {
  scope: functionAppResourceGroup
  name: applicationInsightsName
  params: {
    name: applicationInsightsName
    linkedResourceId: resourceId(subscription().subscriptionId, functionAppResourceGroup.name, 'Microsoft.Web/sites', functionAppName)
    logAnalyticsId: logAnalytics.outputs.id
    location: location
    tags: tags
  }
  dependsOn:[
    functionAppResourceGroupDeploy
  ]
}
module hostingPlan 'modules/serverFarm-consumption.bicep' = {
  scope: functionAppResourceGroup
  name: hostingPlanName
  params: {
    name: hostingPlanName
    operatingSystem: 'Linux'
    location: location
    tags: tags
  }
  dependsOn:[
    functionAppResourceGroupDeploy
  ]
}
module functionApp 'modules/functionApp-dotnet.bicep' = {
  scope: functionAppResourceGroup
  name: functionAppName
  params: {
    functionAppName: functionAppName
    hostingPlanId: hostingPlan.outputs.id
    appInsightsId: appInsights.outputs.id
    dailyMemoryTimeQuota: dailyMemoryTimeQuota
    netFrameworkVersion: '6.0'
    logAnalyticsRetentionDays: 90
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    tags: tags
    location: location
  }
}
module functionAppStorageAccess 'modules/storageAccount-roleassignment.bicep' = [for roleId in [
  roleStorageAccountContributor
  roleStorageBlobDataOwner
  roleStorageTableDataContributor
  roleStorageQueueDataContributor
]: {
  scope: functionAppResourceGroup
  name: 'func2stor-${roleId}'
  params: {
    roleDefinitionId: roleId
    storageAccountName: storageAccount.outputs.name
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storageAccount
  ]
}]
module adminStorageAccess 'modules/storageAccount-roleassignment.bicep' = [for roleId in [
  roleStorageAccountContributor
  roleStorageBlobDataOwner
  roleStorageTableDataContributor
  roleStorageQueueDataContributor
]: if (adminPrincipalId != '') {
  scope: functionAppResourceGroup
  name: 'admin2stor-${roleId}'
  params: {
    roleDefinitionId: roleId
    storageAccountName: storageAccount.outputs.name
    principalId: adminPrincipalId
    principalType: adminPrincipalType
  }
  dependsOn: [
    storageAccount
  ]
}]
module functionAppKeyVault 'modules/keyvault-rbac.bicep' = {
  scope: functionAppResourceGroup
  name: functionAppKeyVaultName
  params: {
    name: functionAppKeyVaultName
    diagnosticsLogAnalyticsResourceId: logAnalytics.outputs.id
    diagnosticsLogAnalyticsWorkspaceRetention: 90
    diagnosticsStorageResourceId: storageAccount.outputs.id
    diagnosticsStorageRetention: 365
    enableSoftDelete: false
    location: location
    tags: tags
  }
}
module functionAppAccessToFunctionAppKeyVault 'modules/keyvault-roleassignment.bicep' = {
  scope: functionAppResourceGroup
  name: 'app2appKV-RBAC'
  params: {
    roleDefinitionId: roleKeyVaultSecretsOfficer
    keyVaultName: functionAppKeyVault.outputs.name
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}
module adminAccessToFunctionAppKeyVault 'modules/keyvault-roleassignment.bicep' = if (adminPrincipalId != '') {
  scope: functionAppResourceGroup
  name: 'admin2appKV-RBAC'
  params: {
    roleDefinitionId: roleKeyVaultSecretsOfficer
    keyVaultName: functionAppKeyVault.outputs.name
    principalId: adminPrincipalId
    principalType: adminPrincipalType
  }
}
module keyVaultResourceGroupDeploy 'modules/resourceGroup.bicep' = {
  scope: subscription(keyVaultSubscriptionId)
  name: keyVaultResourceGroupName
  params: {
    resourceGroupName: keyVaultResourceGroupName
    tags: tags
    location: location
  }
}
resource keyVaultResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription(keyVaultSubscriptionId)
  name: keyVaultResourceGroupName
}
module secretsKeyVault 'modules/keyvault-rbac.bicep' = {
  scope: keyVaultResourceGroup
  name: keyVaultName
  params: {
    name: keyVaultName
    diagnosticsLogAnalyticsResourceId: logAnalytics.outputs.id
    diagnosticsLogAnalyticsWorkspaceRetention: 90
    diagnosticsStorageResourceId: storageAccount.outputs.id
    diagnosticsStorageRetention: 365
    enableSoftDelete: false
    location: location
    tags: tags
  }
  dependsOn:[
    keyVaultResourceGroupDeploy
  ]
}
module functionAppAccessToSecretsKeyVault 'modules/keyvault-roleassignment.bicep' = {
  scope: keyVaultResourceGroup
  name: 'func2secretsKV-RBAC'
  params: {
    roleDefinitionId: roleKeyVaultSecretsUser
    keyVaultName: secretsKeyVault.outputs.name
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}
module adminAccessToSecretsKeyVault 'modules/keyvault-roleassignment.bicep' = if (adminPrincipalId != '') {
  scope: keyVaultResourceGroup
  name: 'admin2secretsKV-RBAC'
  params: {
    roleDefinitionId: roleKeyVaultSecretsOfficer
    keyVaultName: secretsKeyVault.outputs.name
    principalId: adminPrincipalId
    principalType: adminPrincipalType
  }
}
module secrets 'modules/keyvault-secret.bicep' = [for secret in secretsList: {
  scope: keyVaultResourceGroup
  name: 'secret-${secret.name}'
  params: {
    keyVaultName: secretsKeyVault.outputs.name
    secretName: secret.name
    secretValue: secret.value
  }
}]
module functionAppSettings 'modules/functionApp-appSettings.bicep' = {
  scope: functionAppResourceGroup
  name: 'functionAppSettings'
  params: {
    customAppSettings: {
      StorageQueueConnection__credential: 'managedidentity'
      // StorageQueueConnection__queueServiceUri: reference(resourceId(subscription().subscriptionId, functionAppResourceGroupName, 'Microsoft.Storage/storageAccounts', storageAccountName), '2021-09-01').primaryEndpoints.queue
      StorageQueueConnection__queueServiceUri: 'https://${storageAccountName}.queue.${environment().suffixes.storage}/'
      StorageTableConnection__credential: 'managedidentity'
      // StorageTableConnection__tableServiceUri: reference(resourceId(subscription().subscriptionId, functionAppResourceGroupName, 'Microsoft.Storage/storageAccounts', storageAccountName), '2021-09-01').primaryEndpoints.table
      StorageTableConnection__tableServiceUri: 'https://${storageAccountName}.table.${environment().suffixes.storage}/'
      Twitch_CallbackUrl: 'https://${functionApp.outputs.defaultHostName}/api/SubscriptionCallBack'
      DISABLE_NOTIFICATIONS: 'false'
      DiscordTemplateOnFollow: discordTemplateOnFollow
      DiscordTemplateOnStreamOnline: discordTemplateOnStreamOnline
      DiscordWebhookUri: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=DiscordWebhookUri)'
      queueAddSubscription: 'addsubscription'
      queueRemoveSubscription: 'removesubscription'
      queueDiscordHandler: 'discordmessage'
      queueEventOnFollow: 'onfollowevent'
      queueEventOnStreamOnline: 'onstreamonlineevent'
      queueEventOnStreamOffline: 'onstreamofflineevent'
      queueTwitterHandler: 'twittertweet'
      Twitch_ClientId: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=TwitchClientId)'
      Twitch_ClientSecret: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=TwitchClientSecret)'
      Twitch_SignatureSecret: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=TwitchSignatureSecret)'
      TwitterConsumerKey: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=TwitterConsumerKey)'
      TwitterConsumerSecret: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=TwitterConsumerSecret)'
      TwitterAccessToken: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=TwitterAccessToken)'
      TwitterAccessTokenSecret: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=TwitterAccessTokenSecret)'
      TwitterTemplateOnFollow: twitterTemplateOnFollow
      TwitterTemplateOnStreamOnline: twitterTemplateOnStreamOnline
    }
    appInsightsResourceId: appInsights.outputs.id
    functionAppName: functionApp.outputs.name
    functionKeysKeyVaultUri: functionAppKeyVault.outputs.vaultUri
    webJobsStorageAccountName: storageAccount.outputs.name
    workerProcessCount: 10
    workerRuntime: 'dotnet-isolated'
    packageUri: packageUri
  }
  dependsOn: [
    secrets
  ]
}
module deployCode 'modules/deployFunctionCode.bicep' = {
  scope: functionAppResourceGroup
  name: 'deployCode'
  params: {
    siteName: functionApp.outputs.name 
    storageAccountName: storageAccount.outputs.name
    keyVaultName: secretsKeyVault.outputs.name
    keyVaultResourgeGroupName: keyVaultResourceGroupName
    keyVaultSubscriptionId: keyVaultSubscriptionId
    functionKeySecretName: functionKeySecretName
    packageName: packageName
    version: version
    location: location
  }
  dependsOn: [
    functionAppSettings
  ]
}

output FunctionKeySecretPortal string = deployCode.outputs.secretLink
output FunctionAppName string = functionApp.name
output FunctionAppId string = functionApp.outputs.id
output CallBackUrl string = 'https://${functionApp.outputs.defaultHostName}/api/SubscriptionCallBack'
output PrincipalTenantId string = functionApp.outputs.principalTenantId
output PrincipalId string = functionApp.outputs.principalId
output StorageAccountName string = storageAccount.outputs.name
output PackageUri string = packageUri
output KeyVaultResourceId string = secretsKeyVault.outputs.id
