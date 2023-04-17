param name string
param zone string
param tags object = {}
param registrationEnabled bool = false
param vnetIds array
param aRecords array = []

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: zone
  location: 'Global'
  tags: tags  
}

module privateDnsZoneLinks 'privateDnsZoneLink.module.bicep' = if (!empty(vnetIds)) {
  name: take('PDZLink-${name}', 64)  
  params: {
    privateDnsZoneName: privateDnsZone.name
    vnetIds: vnetIds
    registrationEnabled: registrationEnabled
    tags: tags
  }
}

resource dnsRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [for (aRecord, i) in aRecords: {
  parent: privateDnsZone
  name: '${aRecord.name}'
  properties: {
    ttl: 60
    aRecords: [
      {
        ipv4Address: aRecord.ipv4Address
      }
    ]
  }
}]

output id string = privateDnsZone.id
output linkIds array = privateDnsZoneLinks.outputs.ids
