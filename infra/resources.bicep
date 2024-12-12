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
@description('The base64 encoded SSL certificate file in PFX format to be stored in Key Vault. CN and SAN must match the custom hostname of API Management Service.')
param base64certificateText string
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

var resourceNames = {
  storageAccount: naming.storageAccount.nameUnique
  keyVault: naming.keyVault.name
  redis: naming.redisCache.name
  mariadb: '${applicationName}db'
  containerAppName: 'wordpress'
  applicationGateway: naming.applicationGateway.name
}
var secretNames = {
  connectionString: 'storageConnectionString'
  storageKey: 'storageKey'
  certificateKeyName: 'certificateName'
  redisConnectionString: 'redisConnectionString'
  redisPrimaryKeyKeyName: 'redisPrimaryKey'
  redisPasswordName: 'redisPassword'
}
var storagePrivateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
var mariadbPrivateDnsZoneName = 'privatelink.mysql.database.azure.com'
var storageShare = 'smbfileshare'

//1. Networking
module network 'network.bicep' = {
  name: 'network-deployment'
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
          enabledProtocols: 'SMB'
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
    location: 'global'
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
    databases: [
      {
        charset: 'utf8'
        collation: 'utf8_general_ci'
        name: 'wordpress'
      }
    ]
  }
}

resource mariadbSecureConnection 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-12-30' = {
  name: '${resourceNames.mariadb}/require_secure_transport'
  dependsOn: [
    mariadb
  ]
  properties: {
    value: 'OFF'
    source: 'user-override'
  }
}

module mariaDbPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.6.0' ={
  name: 'mariaDbPrivateDnsZone-deployment'
  params: {
    name: mariadbPrivateDnsZoneName
    location: 'global'
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
    location: 'global'
    name: 'privatelink.redis.cache.windows.net'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: network.outputs.vnetResourceId
      }
    ]
  }
}

//4. Keyvault
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'keyVault-deployment'
  params: {
    name: resourceNames.keyVault
    location: location
    sku: 'premium'
    tags: tags
    secrets: (!empty(base64certificateText)) ? [
      {
        name: secretNames.certificateKeyName
        value: base64certificateText
        contentType: 'application/x-pkcs12'
        attributes: {
          enabled: true
        }
      }
    ] : []
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

//5. Container Apps
module wordpressapp 'containerapp.bicep' = {
  name: 'wordpressapp-deployment'
  dependsOn:[
    storage
  ]
  params: {
    tags: tags
    location: location    
    containerAppName: resourceNames.containerAppName
    wordpressFqdn: wordpressFqdn
    infraSnetId: network.outputs.infraSnetResourceId
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    storageAccountName: resourceNames.storageAccount
    storageShareName: storageShare
    dbHost: mariadb.outputs.fqdn
    dbPassword: mariaDBPassword
    redisDeploymentOption: redisDeploymentOption
    managedRedisName: (redisDeploymentOption == 'managed') ? redis.outputs.name : ''
    wordpressImage: wordpressImage
  }
}

//7. DNS Zone for created endpoint
module envdnszone 'br/public:avm/res/network/private-dns-zone:0.6.0' = {
  name: 'envdnszone-deployment'
  params: {
    name: wordpressapp.outputs.envSuffix
    location: 'global'
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
    envdnszone
  ]
  params: {
    name: resourceNames.applicationGateway
    location: location
    subnetId: network.outputs.agwSnetResourceId
    backendFqdn: wordpressapp.outputs.webFqdn
    appGatewayFQDN: wordpressFqdn
    keyVaultName: resourceNames.keyVault
    certificateKeyName: (!empty(base64certificateText))? secretNames.certificateKeyName : ''
    logAnalyticsWorkspaceId: logAnalytics.outputs.resourceId
    tags: tags
  }
}

module jumphost 'jumphost.bicep' = if (deployJumpHost) {
  name: 'jumphost-deployment'
  params: {
    subnetId: network.outputs.appSnetResourceId
    location: location
    tags: tags
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
