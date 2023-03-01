param tags object = {}
param location string

@allowed([
  'Consumption'
  'Premium'
])
param sku string = 'Consumption'
param logAnalytics object
param infraSnetId string
param storageAccountName string
@secure()
param storageAccountKey string
param storageShareName string

var containerEnvName = 'app-container-env'

resource containerEnvironment 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: containerEnvName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.customerId
        sharedKey: logAnalytics.sharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: infraSnetId
      internal: true
    }
    zoneRedundant: false
  }
}

resource webStorage 'Microsoft.App/managedEnvironments/storages@2022-06-01-preview' = {
  name: 'webstorage'
  parent: containerEnvironment
  properties: {
    azureFile: {
      accessMode: 'ReadWrite'
      accountKey: storageAccountKey
      accountName: storageAccountName
      shareName: storageShareName
    }
  }
}

output containerEnvId string = containerEnvironment.id
output webStorageName string = webStorage.name
output envSuffix string = containerEnvironment.properties.defaultDomain
output loadBalancerIP string = containerEnvironment.properties.staticIp

