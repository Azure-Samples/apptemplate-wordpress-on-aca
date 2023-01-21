param name string
param tags object = {}
param registrationEnabled bool = false
param vnetIds array
param aRecords array = []

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'Global'
  tags: tags  
}

module privateDnsZoneLinks 'privateDnsZoneLink.module.bicep' = if (!empty(vnetIds)) {
  name: 'PrvDnsZoneVnetLink'  
  params: {
    privateDnsZoneName: privateDnsZone.name
    vnetIds: vnetIds
    registrationEnabled: registrationEnabled
    tags: tags
  }
}

resource dnsRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [for (aRecord, i) in aRecords: {
  name: '${name}/${aRecord.name}'
  properties: {
    ttl: 60
    aRecords: [
      {
        ipv4Address: aRecord.ipv4Address
      }
    ]
  }
  dependsOn: [
    privateDnsZone
  ]
}]

output id string = privateDnsZone.id
output linkIds array = privateDnsZoneLinks.outputs.ids
