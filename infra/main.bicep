targetScope = 'subscription'

// ======================== //
// Parameters with defaults //
// ======================== //
@description('Azure region where the resources will be deployed in')
@allowed([
  'Australia East' 
  'Brazil South' 
  'Canada Central'
  'Central US'
  'East Asia'
  'East US'
  'East US 2'
  'France Central'
  'Germany West Central'
  'Japan East'
  'Korea Central'
  'North Central US'
  'North Central US (Stage)'
  'North Europe'
  'Norway East'
  'South Africa North'
  'South Central US'
  'Switzerland North'
  'UAE North'
  'UK South'
  'West Europe'
  'West US'
  'West US 3'])
param location string
@description('Id of the user or app to assign application roles')
param principalId string = ''
param environmentName string = 'dev'
@description('Whether to use a custom SSL certificate or not. If set to true, the certificate must be provided in the path cert/certificate.pfx.')
param useCertificate bool = false
@description('Whether to deploy the jump host or not')
param deployJumpHost bool = true
param tags object = {}
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
@description('Whether to deploy a redis cache for the wordpress instance or not.')
param deployWithRedis bool

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

//  Outputs
output AZURE_RESOURCE_GROUP string = rg.name
output AZD_PIPELINE_PROVIDER string = 'github'
output AZURE_ENV_NAME string = environmentName
output AZURE_LOCATION string = location
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId

output APP_ADMIN_USERNAME string = adminUsername
output APP_APPLICATION_NAME string = applicationName
output APP_FQDN string = fqdn
output APP_DEPLOY_REDIS bool = deployWithRedis
