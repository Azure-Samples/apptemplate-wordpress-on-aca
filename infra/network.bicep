targetScope = 'resourceGroup'

param naming object
param tags object = {}
param location string

var isProd = contains(resourceGroup().name, 'prod')
var resourceNames = {
  bastion: naming.bastionHost.name
  vnet: naming.virtualNetwork.name
}

module vnet 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'vnet-deployment'
  params: {
    name: resourceNames.vnet
    location: location
    tags: tags
    addressPrefixes: isProd ? ['10.0.0.0/16'] : ['10.0.0.0/16']
    subnets: [
      {
        name: 'appSnet'
        addressPrefix: isProd ? '10.0.1.0/24' : '10.0.1.0/24'
        serviceEndpoints: [
          'Microsoft.Storage'
          'Microsoft.Sql'
        ]
      }
      {
        name: 'infraSnet'
        addressPrefix: isProd ? '10.0.2.0/23' : '10.0.2.0/23'
        serviceEndpoints: [
          'Microsoft.Storage'
          'Microsoft.Sql'
        ]
        delegation: 'Microsoft.App/environments'
      }
      {
        name: 'storageSnet'
        addressPrefix: isProd ? '10.0.4.0/27' : '10.0.4.0/27'
        networkSecurityGroupResourceId: storageNsg.outputs.resourceId
        privateEndpointNetworkPolicies: 'Enabled'
      }
      {
        name: 'mariaDbSnet'
        addressPrefix: isProd ? '10.0.5.0/27' : '10.0.5.0/27'
        networkSecurityGroupResourceId: mariaDbNsg.outputs.resourceId
        privateEndpointNetworkPolicies: 'Enabled'
        delegation: 'Microsoft.DBforMySQL/flexibleServers'
      }
      {
        name: 'redisSnet' 
        addressPrefix: isProd ? '10.0.6.0/27' : '10.0.6.0/27'
        privateEndpointNetworkPolicies: 'Enabled'
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: isProd ? '10.0.0.0/25' : '10.0.0.0/25'
        networkSecurityGroupResourceId: bastionNsg.outputs.resourceId
      }
      {
        name: 'agwSnet'
        addressPrefix: isProd ? '10.0.127.0/25' : '10.0.127.0/25'
        networkSecurityGroupResourceId: agwNsg.outputs.resourceId
      }
    ]
  }
}

module bastion 'br/public:avm/res/network/bastion-host:0.5.0' = {
  name: 'bastion-deployment'
  params: {
    name: resourceNames.bastion
    location: location
    tags: tags
    virtualNetworkResourceId: vnet.outputs.resourceId
  }
}

module storageNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'storageNsg-deployment'
  params: {
    location: location
    tags: tags
    name: 'storage-${naming.networkSecurityGroup.name}'
    securityRules:[
      {
        name: 'HTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

module mariaDbNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'mariaDbNsg-deployment'
  params: {
    location: location
    tags: tags
    name: 'mariaDb-${naming.networkSecurityGroup.name}'
    securityRules:[
      {
        name: 'MARIADB'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
    ]
  }
}

module bastionNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'bastionNsg-deployment'
  params: {
    location: location
    tags: tags
    name: 'bastion-${naming.networkSecurityGroup.name}'
    securityRules:[
      {
        name: 'HTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      {
        name: 'BASTION'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 400
          direction: 'Inbound'
        }
      }
      {
        name: 'BASTION2'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '5701'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 410
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSSH-outbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 300
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowRDP-outbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 310
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzure-outbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 400
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastion-outbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 500
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastion2-outbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '5701'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 510
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSession-outbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 600
          direction: 'Outbound'
        }
      }
    ]
  }
}

module agwNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'agwNsg-deployment'
  params: {
    location: location
    tags: tags
    name: 'agw-${naming.networkSecurityGroup.name}'
    securityRules:[
      {
        name: 'GWMANAGER'
        properties: {
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AzureLoadBalancer'
        properties: {
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'HTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'HTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAll'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 140
          direction: 'Inbound'
        }
      }
    ]
  }
}

output vnetResourceId string = vnet.outputs.resourceId
output appSnetResourceId string = vnet.outputs.subnetResourceIds[0]
output infraSnetResourceId string = vnet.outputs.subnetResourceIds[1]
output storageSnetResourceId string = vnet.outputs.subnetResourceIds[2]
output mariaDbSnetResourceId string = vnet.outputs.subnetResourceIds[3]
output redisSnetResourceId string = vnet.outputs.subnetResourceIds[4]
output agwSnetResourceId string = vnet.outputs.subnetResourceIds[6]
