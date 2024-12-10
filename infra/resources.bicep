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
var storagePrivateDnsZoneName = 'privatelink.file.core.windows.net'
var mariadbPrivateDnsZoneName = 'mysql.database.azure.com'
var storageShare = 'nfsfileshare'

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
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.9.0' = {
  name: 'loganalytics-deployment'
  params: {
    location: location
    tags: tags
    name: applicationName
  }
}
module appInsights 'br/public:avm/res/insights/component:0.4.2' = {
  name: 'appInsights-deployment'
  params: {
    location: location
    tags: tags
    name: applicationName
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType: 'web'
    kind: 'web'
  }
}
//2. Storage
module storage 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'storage-deployment'
  params: {
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    name: resourceNames.storageAccount
    secretsExportConfiguration: {
      keyVaultResourceId: keyVault.outputs.resourceId
      accessKey1: secretNames.storageKey
    }
    fileServices: {
      shares: [
        {
          enabledProtocols: 'NFS'
          name: storageShare
        }
      ]
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: storagePrivateDnsZone.outputs.resourceId
            }
          ]
        }
        service: 'file'
        subnetResourceId: network.outputs.storageSnetResourceId
      }
    ]
    tags: tags
  }
}
module storagePrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.6.0' = {
  name: 'storagePrivateDnsZone-deployment'
  params: {
    location: location
    name: storagePrivateDnsZoneName
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: network.outputs.vnetResourceId
      }
    ]
  }
}

//3. Database
module mariadb 'br/public:avm/res/db-for-my-sql/flexible-server:0.4.1' = {
  name: 'mariaDB-deployment'
  params: {
    // Required parameters
    name: resourceNames.mariadb
    skuName: 'Standard_D2ds_v4'
    tier: 'GeneralPurpose'
    // Non-required parameters
    administratorLogin: mariaDBAdmin
    administratorLoginPassword: mariaDBPassword
    location: location
    storageAutoGrow: 'Enabled'
    delegatedSubnetResourceId: network.outputs.mariaDbSnetResourceId
    privateDnsZoneResourceId: mariaDbPrivateDnsZone.outputs.resourceId
  }
}

module mariaDbPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.6.0' ={
  name: 'mariaDbPrivateDnsZone-deployment'
  params: {
    name: mariadbPrivateDnsZoneName
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: network.outputs.vnetResourceId
      }
    ]
  }
}

//4. Redis
module redis 'br/public:avm/res/cache/redis:0.8.0' = if (redisDeploymentOption == 'managed') {
  name: 'redis-deployment'
  params: {
    location: location
    name: resourceNames.redis
    tags: tags
    skuName: 'Premium'
    capacity: 1
    publicNetworkAccess: 'Disabled' 
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: redisPrivateDnsZone.outputs.resourceId
            }
          ]
        }
        subnetResourceId: network.outputs.redisSnetResourceId
      }
    ]
  }
}

module redisPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.6.0' = if (redisDeploymentOption == 'managed') {
  name: 'redisPrivateDnsZone-deployment'
  params: {
    location: location
    name: 'privatelink.redis.cache.windows.net'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: network.outputs.vnetResourceId
      }
    ]
  }
}

resource existingRedis 'Microsoft.Cache/Redis@2019-07-01' existing = if (redisDeploymentOption == 'managed') {
  name: resourceNames.redis
}

//4. Keyvault
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'keyVault-deployment'
  params: {
    name: resourceNames.keyVault
    location: location
    sku: 'premium'
    tags: tags
    secrets: [
      {
        name:secretNames.redisConnectionString
        value: '${resourceNames.redis}.redis.cache.windows.net,abortConnect=false,ssl=true,password=${existingRedis.listKeys().primaryKey}'
      }
      {
        name: secretNames.redisPrimaryKeyKeyName
        value: existingRedis.listKeys().primaryKey
      }
      {
        name: secretNames.redisPasswordName
        value: existingRedis.listKeys().primaryKey
      }
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
  name: '${resourceNames.keyVault}/${secretNames.certificateKeyName}'
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
    mariadb
    logAnalytics
  ]
  params: {
    tags: tags
    location: location    
    containerAppName: resourceNames.containerAppName
    wordpressFqdn: wordpressFqdn
    infraSnetId: network.outputs.infraSnetResourceId
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    storageAccountName: resourceNames.storageAccount
    storageShareName: storageShare
    dbHost: mariadb.outputs.fqdn
    dbUser: mariaDBAdmin
    dbPassword: vault.getSecret(secretNames.mariaDBPassword)
    redisDeploymentOption: redisDeploymentOption
    redisManagedFqdn: (!empty(redisDeploymentOption) && redisDeploymentOption == 'managed')? redis.outputs.hostName : ''
    redisManagedPassword: (!empty(redisDeploymentOption) && redisDeploymentOption == 'managed')? vault.getSecret(secretNames.redisPasswordName) : ''
    wordpressImage: wordpressImage
  }
}

//7. DNS Zone for created endpoint
module envdnszone 'br/public:avm/res/network/private-dns-zone:0.6.0' = {
  name: 'envdnszone-deployment'
  params: {
    name: wordpressapp.outputs.envSuffix
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: network.outputs.vnetResourceId
      }
    ]
    a: [
      {
        name: '*'
        aRecords: [
          {
            ipv4Address: wordpressapp.outputs.loadBalancerIP
          }
        ]
        ttl: 60
      }
    ]
    tags: tags
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
    subnetId: network.outputs.agwSnetResourceId
    backendFqdn: wordpressapp.outputs.webFqdn
    appGatewayFQDN: wordpressFqdn
    keyVaultName: resourceNames.keyVault
    certificateKeyName: (useCertificate)? secretNames.certificateKeyName : ''
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
    tags: tags
  }
}

module jumphost 'jumphost.bicep' = if (deployJumpHost) {
  name: 'jumphost-deployment'
  params: {
    naming: naming
    subnetId: network.outputs.appSnetResourceId
    location: location
    tags: tags
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
