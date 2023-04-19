targetScope = 'resourceGroup'

@description('A descriptive name for the resources to be created in Azure')
param applicationName string
@description('This is the fqdn exposed by this wordpress instance. Note this must much the certificate')
param wordpressFqdn string
@description('Naming principles implementation')
param naming object
param tags object = {}
@description('The location where resources will be deployed')
param location string
param mariaDBAdmin string = 'db_admin'
@secure()
param mariaDBPassword string
@description('Whether to use a custom SSL certificate or not. If set to true, the certificate must be provided in the path cert/certificate.pfx.')
param useCertificate bool = false
@description('Whether to deploy the jump host or not')
param deployJumpHost bool = false
param adminUsername string = 'hostadmin'
@secure()
param adminPassword string = ''
@description('The principal ID of the service principal that will be deploying the resources. If not specified, the current user will be used.')
param principalId string = ''
@description('The redis cache deployment option. Valid values are: managed, container, local.')
param redisDeploymentOption string = 'container'
@description('The wordpress container image to use.')
param wordpressImage string = 'kpantos/wordpress-alpine-php:latest'

@description('The path to the base64 encoded SSL certificate file in PFX format to be stored in Key Vault. CN and SAN must match the custom hostname of API Management Service.')
var sslCertPath = 'cert/certificate.pfx'
var resourceNames = {
  storageAccount: naming.storageAccount.nameUnique
  keyVault: naming.keyVault.name
  redis: naming.redisCache.name
  mariadb: naming.mariadbDatabase.name
  containerAppName: 'wordpress'
  applicationGateway: naming.applicationGateway.name
}
var secretNames = {
  connectionString: 'storageConnectionString'
  storageKey: 'storageKey'
  certificateKeyName: 'certificateName'
  redisConnectionString: 'redisConnectionString'
  mariaDBPassword: 'mariaDBPassword'
  redisPrimaryKeyKeyName: 'redisPrimaryKey'
  redisPasswordName: 'redisPassword'
}


//1. Networking
module network 'network.bicep' = {
  name: 'vnet-deployment'
  params: {
    location: location
    tags: tags
    naming: naming
  }
}
//Log Analytics - App insights
module logAnalytics 'modules/appInsights.module.bicep' = {
  name: 'loganalytics-deployment'
  params: {
    location: location
    tags: tags
    name: applicationName
  }
}

//2. Storage
module storage 'modules/storage.module.bicep' = {
  name: 'storage-deployment'
  dependsOn:[keyVault]
  params: {
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    name: resourceNames.storageAccount
    secretNames: secretNames
    keyVaultName: resourceNames.keyVault
    tags: tags
  }
}

module storagePrivateDnsZone 'modules/privateDnsZone.module.bicep'={
  name: 'storagePrivateDnsZone-deployment'
  params: {
    name: 'stgprivatednszone'
    #disable-next-line no-hardcoded-env-urls
    zone: 'privatelink.file.core.windows.net'
    vnetIds: [
      network.outputs.vnetId
    ] 
  }
}
module storagePrivateEndpoint 'modules/privateEndpoint.module.bicep' = {
  name: 'storagePrivateEndpoint-deployment'
  params: {
    location: location
    name: 'pe-${resourceNames.storageAccount}'
    tags: tags
    privateDnsZoneId: storagePrivateDnsZone.outputs.id
    privateLinkServiceId: storage.outputs.id
    subnetId: network.outputs.storageSnetId
    subResource: 'file'
  }  
}

//3. Database
module mariaDB 'modules/mariaDB.module.bicep' = {
  name: 'mariaDB-deployment'
  params: {
    dbPassword: mariaDBPassword
    location: location
    serverName: resourceNames.mariadb
    tags: tags
    administratorLogin: mariaDBAdmin
    useFlexibleServer: false
  }
}

module mariaDbPrivateDnsZone 'modules/privateDnsZone.module.bicep'={
  name: 'mariaDbPrivateDnsZone-deployment'
  params: {
    name: 'mariadbprivatednszone'
    zone: 'privatelink.mariadb.database.azure.com'
    vnetIds: [
      network.outputs.vnetId
    ] 
  }
}
module mariaDbPrivateEndpoint 'modules/privateEndpoint.module.bicep' = {
  name: 'mariaDbPrivateEndpoint-deployment'
  params: {
    location: location
    name: 'pe-${resourceNames.mariadb}'
    tags: tags
    privateDnsZoneId: mariaDbPrivateDnsZone.outputs.id
    privateLinkServiceId: mariaDB.outputs.id
    subnetId: network.outputs.mariaDbSnetId
    subResource: 'mariadbServer'
  }  
}

//4. Redis
module redis 'modules/redis.module.bicep' = if (redisDeploymentOption == 'managed') {
  name: 'redis-deployment'
  params: {
    location: location
    name: resourceNames.redis
    tags: tags
    skuName: 'Premium'
    skuFamily: 'P'
    skuCapacity: 1
    keyVaultName: vault.name
    publicNetworkAccess: 'Disabled'
    saveKeysToVault: (redisDeploymentOption == 'managed')
    connStrKeyName: secretNames.redisConnectionString    
    passwordKeyName: secretNames.redisPasswordName
    primaryKeyKeyName: secretNames.redisPrimaryKeyKeyName
  }
}

module redisPrivateDnsZone 'modules/privateDnsZone.module.bicep'= if (redisDeploymentOption == 'managed') {
  name: 'redisPrivateDnsZone-deployment'
  params: {
    name: 'redisprivatednszone'
    zone: 'privatelink.redis.cache.windows.net'
    vnetIds: [
      network.outputs.vnetId
    ]
  }
}
module redisPrivateEndpoint 'modules/privateEndpoint.module.bicep' = if (redisDeploymentOption == 'managed') {
  name: 'redisPrivateEndpoint-deployment'
  params: {
    location: location
    name: 'pe-${resourceNames.redis}'
    tags: tags
    privateDnsZoneId: (redisDeploymentOption == 'managed')? redisPrivateDnsZone.outputs.id : ''
    privateLinkServiceId: (redisDeploymentOption == 'managed')? redis.outputs.id : ''
    subnetId: network.outputs.redisSnetId
    subResource: 'redisCache'
  }
}

//4. Keyvault
module keyVault 'modules/keyvault.module.bicep' ={
  name: 'keyVault-deployment'
  params: {
    name: resourceNames.keyVault
    location: location
    skuName: 'premium'
    tags: tags
    secrets: [
      {
        name: secretNames.mariaDBPassword
        value: mariaDBPassword
      }
    ]
    accessPolicies: (!empty(principalId))? [
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ] : []
  }  
}

resource sslCertSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (useCertificate) {
  parent: vault
  name: secretNames.certificateKeyName
  dependsOn: [
    keyVault
  ]
  properties: {
    value: loadFileAsBase64(sslCertPath)
    contentType: 'application/x-pkcs12'
    attributes: {
      enabled: true
    }
  }
}

//5. Container Apps
//Get a reference to key vault
resource vault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: resourceNames.keyVault
}
module wordpressapp 'containerapp.bicep' = {
  name: 'wordpressapp-deployment'
  dependsOn:[
    keyVault
    storage
    mariaDB
    logAnalytics
  ]
  params: {
    tags: tags
    location: location    
    containerAppName: resourceNames.containerAppName
    wordpressFqdn: wordpressFqdn
    infraSnetId: network.outputs.infraSnetId
    logAnalytics: logAnalytics.outputs.logAnalytics
    storageAccountName: resourceNames.storageAccount
    storageAccountKey: vault.getSecret(secretNames.storageKey)
    storageShareName: storage.outputs.fileshareName
    dbHost: mariaDB.outputs.hostname
    dbUser: mariaDBAdmin
    dbPassword: vault.getSecret(secretNames.mariaDBPassword)
    redisDeploymentOption: redisDeploymentOption
    redisManagedFqdn: (!empty(redisDeploymentOption) && redisDeploymentOption == 'managed')? redis.outputs.redisHost : ''
    redisManagedPassword: (!empty(redisDeploymentOption) && redisDeploymentOption == 'managed')? vault.getSecret(secretNames.redisPasswordName) : ''
    wordpressImage: wordpressImage
  }
}

//7. DNS Zone for created endpoint
module envdnszone 'modules/privateDnsZone.module.bicep' = {
  name: 'envdnszone-deployment'
  params: {
    name: 'appenvdnszone'
    zone: wordpressapp.outputs.envSuffix
    vnetIds: [
      network.outputs.vnetId
    ]
    aRecords: [
      {
        name: '*'
        ipv4Address: wordpressapp.outputs.loadBalancerIP
      }
    ]
    tags: tags
    registrationEnabled: false
  }
}

//9. application gateway
module agw 'applicationGateway.bicep' = {
  name: 'applicationGateway-deployment'
  dependsOn: [
    keyVault
    wordpressapp
    envdnszone
  ]
  params: {
    name: resourceNames.applicationGateway
    location: location
    subnetId: network.outputs.agwSnetId
    backendFqdn: wordpressapp.outputs.webFqdn
    appGatewayFQDN: wordpressFqdn
    keyVaultName: resourceNames.keyVault
    certificateKeyName: (useCertificate)? secretNames.certificateKeyName : ''
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: tags
  }
}

module jumphost 'jumphost.bicep' = if (deployJumpHost) {
  name: 'jumphost-deployment'
  params: {
    naming: naming
    subnetId: network.outputs.appSnetId
    location: location
    tags: tags
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
