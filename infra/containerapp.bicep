param location string
param tags object = {}
param containerAppName string
param wordpressFqdn string
param infraSnetId string
param logAnalytics object 
param storageAccountName string 
@secure()
param storageAccountKey string
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

var redisHostSecret = (redisDeploymentOption == 'container') ? redisContainer.properties.configuration.ingress.fqdn : (redisDeploymentOption == 'local') ? 'localhost' : redisManagedFqdn
var redisPassword = (redisDeploymentOption == 'managed') ? redisManagedPassword : 'null'

module environment 'modules/containerappsEnvironment.module.bicep' = {
  name: 'containerAppEnv-deployement'
  params: {
    tags: tags
    infraSnetId: infraSnetId
    location: location
    logAnalytics: logAnalytics
    storageAccountKey: storageAccountKey
    storageAccountName: storageAccountName
    storageShareName: storageShareName
  }
}

resource redisContainer 'Microsoft.App/containerApps@2022-10-01' = if (redisDeploymentOption == 'container') {
  name: '${containerAppName}redis'
  location: location
  tags: tags
  properties: {
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 6379
        exposedPort: 6379
        transport: 'tcp'
      }
    }
    environmentId: environment.outputs.containerEnvId
    template: {
      containers: [
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
      scale: {
        minReplicas: 1
      }
      volumes:[]
    }
  }
}

resource wordpressApp 'Microsoft.App/containerApps@2022-10-01' = {
  name: '${containerAppName}web'
  location: location
  tags: tags
  properties: {
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        allowInsecure: true
        external: true
        targetPort: 80
        transport: 'auto'
      }
      secrets: [
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
          value: redisHostSecret
        }
        { 
          name: 'redis-password'
          value: redisPassword
        }
      ]
    }
    environmentId: environment.outputs.containerEnvId
    template: {
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
      scale: {
        minReplicas: 1
      }
      volumes:[
        {
          name: volumename
          storageName: environment.outputs.webStorageName
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

output webFqdn string = wordpressApp.properties.configuration.ingress.fqdn
output redisFqdn string = (redisDeploymentOption == 'container') ? redisContainer.properties.configuration.ingress.fqdn : ''
output webLatestRevisionName string = wordpressApp.properties.latestRevisionName
output envSuffix string = environment.outputs.envSuffix
output loadBalancerIP string = environment.outputs.loadBalancerIP
