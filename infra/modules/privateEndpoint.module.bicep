param name string
param location string
param tags object = {}
param subnetId string
param privateLinkServiceId string
param privateDnsZoneId string

@allowed([
  'sites'
  'sqlServer'   // Microsoft.Sql/servers
  'mysqlServer'
  'postgresqlServer'
  'mariadbServer'
  'blob'
  'file'
  'queue'
  'redisCache'
  'namespace'   
  'Sql'         // Microsoft.Synapse/workspaces
  'vault'
])
param subResource string

var privateLinkConnectionName = 'prvlnk-${name}'
var privateDnsZoneConfigName = 'prvZoneConfig-${name}'

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateLinkConnectionName
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: [
            subResource
          ]
        }
      }
    ]
  }
}

resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-05-01' = {
  parent: privateEndpoint
  name: 'dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneConfigName
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}
