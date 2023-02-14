param serverName string
param location string
param tags object = {}
param administratorLogin string = 'dbadmin'
// param infraSnetId string
// param appSnetId string
@secure()
param dbPassword string
param useFlexibleServer bool = false

resource mySQL 'Microsoft.DBforMariaDB/servers@2018-06-01' = if (!useFlexibleServer) {
  name: serverName
  location: location
  tags: tags
  sku: {
    capacity: 8
    family: 'Gen5'
    name: 'GP_Gen5_8'
    size: '5120'
    tier: 'GeneralPurpose'
  }
  properties: {
    minimalTlsVersion: 'TLSEnforcementDisabled'
    publicNetworkAccess: 'Disabled'
    sslEnforcement: 'Disabled'
    storageProfile: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
      storageAutogrow: 'Enabled'
      storageMB: 5120
    }
    version: '10.2'
    createMode: 'Default'
    administratorLogin: administratorLogin
    administratorLoginPassword: dbPassword
  }
}

resource wordpressdb 'Microsoft.DBforMariaDB/servers/databases@2018-06-01' = if (!useFlexibleServer) {
  name: 'wordpress'
  parent: mySQL
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}

resource flexMySQL 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = if (useFlexibleServer) {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: 'Standard_D8s_v3'
    tier: 'GeneralPurpose'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: dbPassword
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    createMode: 'Default'
    dataEncryption: {
      type: 'SystemManaged'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    replicationRole: 'None'
    storage: {
      autoGrow: 'Enabled'
      iops: 1000
      storageSizeGB: 5
    }
    version: '8.0.21'
  }
}

output id string = (useFlexibleServer)? flexMySQL.id : mySQL.id
output hostname string = (useFlexibleServer)? flexMySQL.properties.fullyQualifiedDomainName : mySQL.properties.fullyQualifiedDomainName
