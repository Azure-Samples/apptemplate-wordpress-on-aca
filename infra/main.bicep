targetScope = 'subscription'

// ======================== //
// Parameters with defaults //
// ======================== //
@description('Azure region where the resources will be deployed in')
@allowed([
  'australiaeast' 
  'brazilsouth' 
  'canadacentral'
  'centralus'
  'eastasia'
  'eastus'
  'eastus2'
  'francecentral'
  'germanywestcentral'
  'japaneast'
  'koreacentral'
  'northcentralus'
  'northeurope'
  'norwayeast'
  'southafricanorth'
  'southcentralus'
  'switzerlandnorth'
  'uaenorth'
  'uksouth'
  'westeurope'
  'westus'
  'westus3'])
param location string
@description('Id of the user or app to assign application roles')
param principalId string = ''
param environmentName string
@description('Whether to use a custom SSL certificate or not. If set to true, the certificate must be provided in the path cert/certificate.pfx.')
param useCertificate bool = false
@description('Whether to deploy the jump host or not')
param deployJumpHost bool = true
param tags object = { 'azd-env-name': environmentName }
@description('The image to use for the wordpress container. Default is kpantos/wordpress-alpine-php:latest')
param wordpressImage string = 'kpantos/wordpress-alpine-php:latest'

// =================== //
// Required Parameters //
@description('The fully qualified name of the application')
param fqdn string
param applicationName string
@secure()
param mariaDBPassword string
@description('The username of the jump host admin user')
param adminUsername string
@secure()
@description('The password of the jump host admin user')
param adminPassword string

@description('The redis cache deployment option. Valid values are: managed, container, local.')
@allowed([
  'managed' 
  'container' 
  'local'])
param redisDeploymentOption string

var defaultTags = union({
  applicationName: applicationName
}, tags)

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${applicationName}'
  location: location
  tags: defaultTags
}

module naming 'modules/naming.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'NamingDeployment'  
  params: {
    suffix: [
      applicationName
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
    redisDeploymentOption: redisDeploymentOption
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

//  Outputs
output AZURE_RESOURCE_GROUP string = rg.name
output AZD_PIPELINE_PROVIDER string = 'github'
output AZURE_ENV_NAME string = environmentName
output AZURE_LOCATION string = location
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId

output APP_ADMIN_USERNAME string = adminUsername
output APP_APPLICATION_NAME string = applicationName
output APP_FQDN string = fqdn
output APP_REDIS_DEPLOYMENT_OPTIONS string = redisDeploymentOption
