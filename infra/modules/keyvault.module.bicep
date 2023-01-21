param name string
param location string = resourceGroup().location
param tags object = {}

@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Array of access policy configurations, schema ref: https://docs.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/accesspolicies?tabs=json#microsoftkeyvaultvaultsaccesspolicies-object')
param accessPolicies array = []

@description('Secrets array with name/value pairs')
param secrets array = []

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    accessPolicies: accessPolicies
    enabledForDeployment: true
    enabledForTemplateDeployment: true
  }
  tags: tags
}

module secretsDeployment 'keyvault.secrets.module.bicep' = if (!empty(secrets)) {
  name: 'keyvault-secrets'
  params: {
    keyVaultName: keyVault.name
    secrets: secrets
  }
}

output id string = keyVault.id
output name string = keyVault.name
output secrets array = secretsDeployment.outputs.secrets
