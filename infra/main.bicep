targetScope = 'subscription'

// =========== //
// Parameters //
// =========== //
@description('Azure region where the resources will be deployed in')
@allowed([
  'eastus'
  'eastus2'
  'southcentralus'
  'westus2'
  'westus3'
  'australiaeast'
  'southeastasia'
  'northeurope'
  'swedencentral'
  'uksouth'
  'westeurope'
  'centralus'
  'southafricanorth'
  'centralindia'
  'eastasia'
  'japaneast'
  'koreacentral'
  'canadacentral'
  'francecentral'
  'germanywestcentral'
  'norwayeast'
  'brazilsouth'
  'eastus2euap'
  'centralusstage'
  'eastusstage'
  'eastus2stage'
  'northcentralusstage'
  'southcentralusstage'
  'westusstage'
  'westus2stage'
  'asia'
  'asiapacific'
  'australia'
  'brazil'
  'canada'
  'europe'
  'france'
  'germany'
  'india'
  'japan'
  'korea'
  'norway'
  'southafrica'
  'switzerland'
  'uae'
  'uk'
  'unitedstates'
  'unitedstateseuap'
  'eastasiastage'
  'southeastasiastage'
  'northcentralus'
  'westus'
  'jioindiawest'
  'switzerlandnorth'
  'uaenorth'
  'centraluseuap'
  'westcentralus'
  'southafricawest'
  'australiacentral'
  'australiacentral2'
  'australiasoutheast'
  'japanwest'
  'jioindiacentral'
  'koreasouth'
  'southindia'
  'westindia'
  'canadaeast'
  'francesouth'
  'germanynorth'
  'norwaywest'
  'switzerlandwest'
  'ukwest'
  'uaecentral'
  'brazilsoutheast'
])
param location string
@description('The fully qualified name of the application')
param fqdn string
param applicationName string
@secure()
param mariaDBPassword string
@description('Id of the user or app to assign application roles')
param principalId string = ''
param environmentName string = 'dev'
@description('Whether to use a custom SSL certificate or not. If set to true, the certificate must be provided in the path cert/certificate.pfx.')
param useCertificate bool = false
@description('Whether to deploy the jump host or not')
param deployJumpHost bool = false
@description('The username of the jump host admin user')
param adminUsername string = 'hostadmin'
@secure()
@description('The password of the jump host admin user')
param adminPassword string = ''
param tags object = {}
@description('Whether to deploy a redis cache for the wordpress instance or not.')
param deployWithRedis bool = false
@description('The image to use for the wordpress container. Default is kpantos/wordpress-alpine-php:latest')
param wordpressImage string = 'kpantos/wordpress-alpine-php:latest'

var defaultTags = union({
  applicationName: applicationName
  environment: environmentName
}, tags)

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${applicationName}-${environmentName}'
  location: location
  tags: defaultTags
}

module naming 'modules/naming.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'NamingDeployment'  
  params: {
    suffix: [
      applicationName
      environmentName
    ]
    uniqueLength: 6
    uniqueSeed: rg.id
  }
}

module main 'resources.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'MainDeployment'
  params: {
    location: location
    naming: naming.outputs.names
    tags: defaultTags
    applicationName: applicationName
    mariaDBPassword: mariaDBPassword
    wordpressFqdn: fqdn
    useCertificate: useCertificate
    deployJumpHost: deployJumpHost
    adminUsername: adminUsername
    adminPassword: adminPassword
    principalId: principalId
    deployWithRedis: deployWithRedis
    wordpressImage: wordpressImage
  }
}

//  Deployment Telemetry
@description('Enable usage and telemetry feedback to Microsoft.')
param enableTelemetry bool = true
var telemetryId = '69ef933a-eff0-450b-8a46-331cf62e160f-wordpress-${location}'
resource telemetrydeployment 'Microsoft.Resources/deployments@2021-04-01' = if (enableTelemetry) {
  name: telemetryId
  location: location
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
      contentVersion: '1.0.0.0'
      resources: {}
    }
  }
}
output resourceGroupName string = rg.name
