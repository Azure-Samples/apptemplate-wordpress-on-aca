param location string
param name string
param tags object = {}
param secretNames object = {}
param virtualNetworkRules array = []
param ipRules array = []

@allowed([
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
  'StorageV2'
])
param kind string = 'StorageV2'

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_LRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param skuName string = 'Standard_LRS'
param keyVaultName string

var fileshareName = 'fileshare'

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: toLower(replace(name, '-', ''))
  location: location
  kind: kind
  sku: {
    name: skuName
  }
  tags: union(tags, {
    displayName: name
  })
  properties: {
    publicNetworkAccess: 'disabled'
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true 
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: virtualNetworkRules
      ipRules: ipRules
    }
  }
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' ={
  name: '${storage.name}/default/${fileshareName}'
  properties: {
    shareQuota: 5
  }
} 

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: secretNames.storageKey
  parent: keyVault
  properties: {
    value: listKeys(storage.id, storage.apiVersion).keys[0].value
  }
}

resource connString 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: secretNames.connectionString
  parent: keyVault
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
  }
}

output id string = storage.id
output name string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints
output fileshareName string = fileshareName
