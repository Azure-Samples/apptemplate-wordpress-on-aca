param location string
param tags object = {}
param containerAppName string
param wordpressFqdn string
param infraSnetId string
param logAnalyticsWorkspaceResourceId string 
param storageAccountName string 
param storageShareName string 
param dbHost string
param dbUser string
@secure()
param dbPassword string
param redisDeploymentOption string = 'container'
param redisManagedFqdn string = ''
@secure()
param redisManagedPassword string = ''
param wordpressImage string = 'kpantos/wordpress-alpine-php:latest'

var dbPort = '3306'
var volumename = 'wpstorage' //sensitive to casing and length. It has to be all lowercase.
var dbName = 'wordpress'

var redisHost = (redisDeploymentOption == 'container') ? redisContainer.outputs.fqdn : (redisDeploymentOption == 'local') ? 'localhost' : redisManagedFqdn
var redisPassword = (redisDeploymentOption == 'managed') ? redisManagedPassword : 'null'
var workloadProfileName = 'default'
var envName = 'app-container-env'

@description('The Azure Container Apps (ACA) cluster.')
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.8.1' = {
  name: 'containerAppEnv-deployement'
  params: {
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    name: envName
    location: location
    tags: tags
    internal: true
    infrastructureSubnetId: infraSnetId
    workloadProfiles: [
      {
        maximumCount: 3
        minimumCount: 0
        name: workloadProfileName
        workloadProfileType: 'D4'
      }
    ]
    storages: [
      {
        accessMode: 'ReadWrite'
        kind: 'SMB'
        shareName: storageShareName
        storageAccountName: storageAccountName
      }
    ]
    zoneRedundant: false
  }
}

module redisContainer 'br/public:avm/res/app/container-app:0.11.0'  = if (redisDeploymentOption == 'container') {
  name: 'redis-deployment'
  params: {
    name: '${containerAppName}redis'
    location: location
    tags: tags
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    containers:[
      {
        args: []
        command: []
        env: []
        image: 'redis:latest'
        name: 'redis'
        probes: []
        resources: {
          cpu: json('1.0')
          memory: '2.0Gi'
        }
        volumeMounts: []
      }
    ]
    activeRevisionsMode: 'Single'
    ingressExternal: true
    ingressTargetPort: 6379
    ingressTransport: 'tcp'
    exposedPort: 6379
    scaleMinReplicas: 1
    workloadProfileName: workloadProfileName
  }
}

module wordpressApp 'br/public:avm/res/app/container-app:0.11.0' = {
  name: 'wordpress-deployment'
  params: {
    name: '${containerAppName}web'
    containers: [
      {
        args: []
        command: []
        env: [
          {
            name: 'DB_HOST'
            secretRef: 'db-host'
          }
          {
            name: 'DB_USER'
            secretRef: 'db-user'
          }
          {
            name: 'DB_NAME'
            secretRef: 'db-name'
          }
          {
            name: 'DB_PASS'
            secretRef: 'db-pass'
          }
          {
            name: 'DB_PORT'
            secretRef: 'db-port'
          }
          {
            name: 'WP_FQDN'
            secretRef: 'wp-fqdn'
          }
          { 
            name: 'REDIS_HOST'
            secretRef: 'redis-host'
          }
          { 
            name: 'REDIS_PASSWORD'
            secretRef: 'redis-password'
          }
        ]
        image: wordpressImage
        name: 'wordpress'
        probes: []
        resources: {
          cpu: json('2.0')
          memory: '4.0Gi'
        }
        volumeMounts: [
          {
            mountPath: '/home'
            volumeName: volumename
          }
        ]
      }
    ]
    secrets: {
      secureList: [
        {
          name: 'db-host'
          value: dbHost
        }
        {
          name: 'db-port'
          value: dbPort
        }
        {
          name: 'db-user'
          value: '${dbUser}@${dbHost}'
        }
        {
          name: 'db-name'
          value: dbName
        }
        {
          name: 'db-pass'
          value: dbPassword
        }
        {
          name: 'wp-fqdn'
          value: wordpressFqdn
        }
        { 
          name: 'redis-host'
          value: redisHost
        }
        { 
          name: 'redis-password'
          value: redisPassword
        }
      ]
    }
    activeRevisionsMode: 'Single'
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    ingressAllowInsecure: true
    ingressExternal: true
    ingressTargetPort: 80
    ingressTransport: 'auto'
    scaleMinReplicas: 1
    workloadProfileName: workloadProfileName
    volumes: [
      {
        name: volumename
        storageName: storageShareName
        storageType: 'AzureFile'
      }
    ]
  }
}


output webFqdn string = wordpressApp.outputs.fqdn
output redisFqdn string = (redisDeploymentOption == 'container') ? redisContainer.outputs.fqdn : ''
output envSuffix string = containerAppsEnvironment.outputs.defaultDomain
output loadBalancerIP string = containerAppsEnvironment.outputs.staticIp
