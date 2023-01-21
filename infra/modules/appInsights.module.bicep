param name string
param location string
param tags object = {}

var workspaceName = 'log-${name}'
var appInsightsName = 'ai-${name}'

resource laWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: workspaceName
  tags: union(tags, {
    displayName: workspaceName
    projectName: name
  })
  properties: {
    retentionInDays: 90
    sku:{
      name:'PerGB2018'
    }
  }
}

resource appIns 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: laWorkspace.id  
  }
}

output id string = appIns.id
output instrumentationKey string = appIns.properties.InstrumentationKey
output workspaceId string = laWorkspace.id
output logAnalytics object = {
  id: laWorkspace.id
  customerId: laWorkspace.properties.customerId
#disable-next-line outputs-should-not-contain-secrets
  sharedKey: laWorkspace.listKeys().primarySharedKey
}
