param siteName string
param storageAccountName string
param packageName string
param keyVaultName string
param keyVaultResourgeGroupName string
param keyVaultSubscriptionId string
param functionKeySecretName string = 'functionAccessKey'
param version string = ''
param tags object = {}
param location string = resourceGroup().location

var roleStorageBlobDataOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var roleWebsiteContributor = 'de139f84-1756-47ae-9be6-808fbbe84772'
var roleKeyVaultSecretsOfficer = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource functionApp 'Microsoft.Web/sites@2021-03-01' existing = {
  name: siteName
}
resource deployScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'TwitchLiveNotification-DeployScript'
  tags: tags
  location: location
}

module storageRbac 'storageAccount-roleassignment.bicep' = {
  name: 'deployScript-storageAccess'
  params: {
    principalId: deployScriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleStorageBlobDataOwner
    storageAccountName: storageAccountName
  }
}

module siteRbac 'site-roleassignment.bicep' = {
  name: 'deployScript-siteAccess'
  params: {
    principalId: deployScriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleWebsiteContributor
    siteName: siteName
  }
}

module secretKVRbac 'keyvault-roleassignment.bicep' = {
  scope: resourceGroup(keyVaultSubscriptionId, keyVaultResourgeGroupName)
  name: 'deployScript-secretKVAccess'
  params: {
    principalId: deployScriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleKeyVaultSecretsOfficer
    keyVaultName: keyVaultName
  }
}

module deploymentScript 'deploymentScript-AzurePowerShell-Inline.bicep' = {
  name: 'deployFunctionScript'
  params: {
    script: '''
    $Uri = "https://github.com/SimonWahlin/TwitchLiveNotifications/releases/$ENV:version/$ENV:packageName"
    Write-Output "Using Uri: $Uri"
    Invoke-WebRequest -Uri $Uri -OutFile "$ENV:packageName"
    Write-Output "Downloaded $ENV:packageName"
    Write-Output "Using storage account: $ENV:storageAccountName"
    $StorageContext = New-AzStorageContext -StorageAccountName $ENV:storageAccountName -UseConnectedAccount
    Set-AzStorageBlobContent -Container 'deploy' -Context $StorageContext -File "$ENV:packageName" -Force
    Invoke-AzRest -Uri "$ENV:resourceManagerEndpoint$ENV:functionAppResourceId/syncfunctiontriggers?api-version=2016-08-01" -Method POST
    for($i=0;$i-lt10;$i++) {
      try {
        $response = Invoke-AzRest -Uri "$ENV:resourceManagerEndpoint$ENV:functionAppResourceId/host/default/listkeys?api-version=2021-03-01" -Method POST -ErrorAction 'Stop'
        if($response.StatusCode -eq 200) {
          Write-Output "Got keys, saving to Key Vault"
          $SecretValue = $response.Content | ConvertFrom-Json | Select-Object -ExpandProperty functionKeys | Select-Object -ExpandProperty default | ConvertTo-SecureString -AsPlainText -Force
          $Secret = Set-AzKeyVaultSecret -VaultName $ENV:keyVaultName -Name $ENV:functionKeySecretName -SecretValue $SecretValue
          $DeploymentScriptOutputs = @{secretLink="$ENV:portalEndpoint#@$ENV:tenantId/asset/Microsoft_Azure_KeyVault/Secret/$($Secret.Id)"}
          return
        }
        Write-Output "Got response: $response.StatusCode, retrying..."
        Start-Sleep -Seconds 30
      }
      catch {
        Write-Output "Got error, retrying..."
        Start-Sleep -Seconds 30
      }
    }
    '''
    environmentVariables: [
      {
        name: 'version'
        value: version == '' || version == 'latest' ? 'latest/download' : 'download/${version}'
      }
      {
        name: 'storageAccountName'
        value: storageAccountName
      }
      {
        name: 'keyVaultName'
        value: keyVaultName
      }
      {
        name: 'functionKeySecretName'
        value: functionKeySecretName
      }
      {
        name: 'packageName'
        value: packageName
      }
      {
        name: 'resourceManagerEndpoint'
        value: environment().resourceManager
      }
      {
        name: 'portalEndpoint'
        value: environment().portal
      }
      {
        name: 'tenantId'
        value: tenant().tenantId
      }
      {
        name: 'functionAppResourceId'
        value: functionApp.id
      }
    ]
    identityResourceId: deployScriptIdentity.id
    location: location
  }
}

output secretLink string = deploymentScript.outputs.scriptOutput.secretLink
