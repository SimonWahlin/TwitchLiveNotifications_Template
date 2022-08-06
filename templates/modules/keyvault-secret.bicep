param keyVaultName string
param secretName string

@secure()
param secretValue string

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: keyVault
  name: secretName
  properties: {
      value: secretValue
  }
}

output id string = secret.id
output secretUri string = secret.properties.secretUri
output secretUriWithVersion string = secret.properties.secretUriWithVersion
