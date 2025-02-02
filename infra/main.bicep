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
@description('The base64 encoded SSL certificate file in PFX format to be stored in Key Vault. CN and SAN must match the custom hostname of the Application Gateway service.')
param base64certificateText string
@description('Whether to deploy the jump host or not')
param deployJumpHost bool
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

var rgName = 'rg-${applicationName}'

module rg 'br/public:avm/res/resources/resource-group:0.4.0'= {
  name: 'ResourceGroupDeployment'
  params: {
    location: location
    tags: defaultTags
    name: rgName
  }
}

module naming 'modules/naming.module.bicep' = {
  scope: resourceGroup(rgName)
  name: 'NamingDeployment'  
  params: {
    suffix: [
      applicationName
    ]
    uniqueLength: 6
    uniqueSeed: rg.outputs.resourceId
  }
}

module main 'resources.bicep' = {
  scope: resourceGroup(rgName)
  name: 'MainDeployment'
  params: {
    location: location
    naming: naming.outputs.names
    tags: defaultTags
    applicationName: applicationName
    mariaDBPassword: mariaDBPassword
    wordpressFqdn: fqdn
    base64certificateText: base64certificateText
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
var telemetryId = '69ef933a-eff0-450b-8a46-331cf62e160f-wordpress'
#disable-next-line no-deployments-resources
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
output AZURE_RESOURCE_GROUP string = rg.outputs.name
output AZD_PIPELINE_PROVIDER string = 'github'
output AZURE_ENV_NAME string = environmentName
output AZURE_LOCATION string = location
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId

output APP_ADMIN_USERNAME string = adminUsername
output APP_APPLICATION_NAME string = applicationName
output APP_FQDN string = fqdn
output APP_REDIS_DEPLOYMENT_OPTIONS string = redisDeploymentOption
