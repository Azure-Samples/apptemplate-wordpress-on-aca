param name string
param location string = resourceGroup().location
param tags object = {}
param keyVaultName string
param connStrKeyName string
param passwordKeyName string
param primaryKeyKeyName string

@allowed([
  'C'
  'P'
])
param skuFamily string = 'C'

@allowed([
  0
  1
  2
  3
  4
  5
  6
])
param skuCapacity int = 1

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

resource redis 'Microsoft.Cache/redis@2020-12-01' = {
  name: name
  location: location
  properties: {
    sku: {
      capacity: skuCapacity
      family: skuFamily
      name: skuName
    }
    publicNetworkAccess: 'Enabled'
    enableNonSslPort: true    
  }
  tags: tags
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource redisKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: primaryKeyKeyName
  parent: keyVault
  properties: {
    value: listKeys(redis.id, redis.apiVersion).primaryKey
  }
}

resource redisConnStr 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  name: connStrKeyName
  parent: keyVault
  properties: {
    value: '${name}.redis.cache.windows.net,abortConnect=false,ssl=true,password=${listKeys(redis.id, redis.apiVersion).primaryKey}'
  }
}
resource redisPassword 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  name: passwordKeyName
  parent: keyVault
  properties: {
    value: listKeys(redis.id, redis.apiVersion).primaryKey
  }
}

output id string = redis.id
output redisHost string = redis.properties.hostName
