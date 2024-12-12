param location string = resourceGroup().location
param tags object = {}
param subnetId string
param adminUsername string = 'hostadmin'
@secure()
param adminPassword string = ''
@description('Required. Specifies the size for the VMs. Default is Standard_F4s_v2.')
param vmSize string = 'Standard_F4s_v2'

var resourceNames = {
  nicName: 'jumphost-nic'
  ipConfigurationName: 'jumphost-nic-ipconfig'
  vmName: 'jumphost'
}

module jumphost 'br/public:avm/res/compute/virtual-machine:0.10.1' = {
  name: 'vm-deployment'
  params: {
    name: resourceNames.vmName
    location: location
    tags: tags
    adminUsername: adminUsername
    adminPassword: adminPassword
    provisionVMAgent: true
    enableAutomaticUpdates: true
    patchMode: 'AutomaticByOS'
    patchAssessmentMode: 'ImageDefault'
    enableHotpatching: false
    bootDiagnostics: true
    computerName: resourceNames.vmName
    encryptionAtHost: false
    vmSize: vmSize
    zone: 1
    osDisk:{
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
      caching: 'ReadWrite'
      diskSizeGB: 128
      createOption: 'FromImage'
    }
    osType: 'Windows'
    imageReference: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'Windows-10'
      sku: 'win10-21h2-pro'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: resourceNames.ipConfigurationName
            subnetResourceId: subnetId
          }
        ]
        nicSuffix: '-nic-01'
      }

    ]
  }
}
