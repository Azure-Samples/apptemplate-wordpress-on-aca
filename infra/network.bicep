targetScope = 'resourceGroup'

param naming object
param tags object = {}
param location string

var isProd = contains(resourceGroup().name, 'prod')
var resourceNames = {
  bastion: naming.bastionHost.name
  vnet: naming.virtualNetwork.name
}

module vnet 'modules/vnet.module.bicep' = {
  name: 'virtualNetwork-deployment'
  params: {
    name: resourceNames.vnet
    location: location
    tags: tags
    includeBastion: true
    addressPrefix: isProd ? '10.0.0.0/16' : '10.0.0.0/16'
    appSnet: {
      addressPrefix: isProd ? '10.0.1.0/24' : '10.0.1.0/24'
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
        }
        {
          service: 'Microsoft.Sql'
        }
      ]
    }
    infraSnet: {
      addressPrefix: isProd ? '10.0.2.0/23' : '10.0.2.0/23'
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
        }
        {
          service: 'Microsoft.Sql'
        }
      ]
    }
    storageSnet:{
      addressPrefix: isProd ? '10.0.4.0/27' : '10.0.4.0/27'
      networkSecurityGroup: {
        id: storageNsg.id
      }
      privateEndpointNetworkPolicies: 'Enabled'       
    }
    mariaDbSnet:{
      addressPrefix: isProd ? '10.0.5.0/27' : '10.0.5.0/27'
      networkSecurityGroup: {
        id: mariaDbNsg.id
      }
      privateEndpointNetworkPolicies: 'Enabled'        
    }
    redisSnet: {
      addressPrefix: isProd ? '10.0.6.0/27' : '10.0.6.0/27'
      privateEndpointNetworkPolicies: 'Enabled'
    }
    bastionSnet: {
      addressPrefix: isProd ? '10.0.0.0/25' : '10.0.0.0/25'
      networkSecurityGroup: {
        id: bastionNsg.id
      }
    }
    agwSnet: {
      addressPrefix: isProd ? '10.0.127.0/25' : '10.0.127.0/25'
      networkSecurityGroup: {
        id: agwNsg.id
      } 
    }
  }
}

module bastion 'modules/bastion.module.bicep' = {
  name: 'bastion-deployment'
  params: {
    name: resourceNames.bastion
    location: location
    tags: tags
    subnetId: vnet.outputs.bastionSnetId
  }
}

resource storageNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'storage-${naming.networkSecurityGroup.name}'
  location: location
  properties: {
    securityRules: [
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
resource mariaDbNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'postgressql-${naming.networkSecurityGroup.name}'
  location: location
  properties: {
    securityRules: [
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

resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'bastion-${naming.networkSecurityGroup.name}'
  location: location
  properties: {
    securityRules: [
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

resource agwNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'agw-${naming.networkSecurityGroup.name}'
  location: location
  properties: {
    securityRules: [
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

output vnetId string = vnet.outputs.vnetId
output appSnetId string = vnet.outputs.appSnetId
output infraSnetId string = vnet.outputs.infraSnetId
output storageSnetId string = vnet.outputs.storageSnetId
output mariaDbSnetId string = vnet.outputs.mariaDbSnetId
output redisSnetId string = vnet.outputs.redisSnetId
output agwSnetId string = vnet.outputs.agwSnetId
