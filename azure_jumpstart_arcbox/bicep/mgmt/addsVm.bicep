@description('The FQDN of the domain')
param addsDomainName string = 'jumpstart.local'

@description('The name of your Virtual Machine')
param vmName string = 'ArcBox-ADDS'

@description('Username for the Virtual Machine')
param windowsAdminUsername string = 'arcdemo'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long.')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string = 'ArcPassword123!!'

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources')
param azureLocation string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_D2s_v4'

@description('Choice to deploy Azure Bastion')
param deployBastion bool = false

@description('Base URL for ARM template')
param templateBaseUrl string = ''

var vmName_var = concat(vmName)
var networkInterfaceName_var = '${vmName}-NIC'
var virtualNetworkName = 'ArcBox-VNet'
var dcSubnetName = 'ArcBox-DC-Subnet'
var addsPrivateIPAddress = '10.16.2.100'
var bastionName = 'ArcBox-Bastion'
var osDiskType = 'Premium_LRS'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, dcSubnetName)
var networkInterfaceRef = networkInterfaceName.id
var publicIpAddressName_var = ((!deployBastion) ? '${vmName}-PIP' : '${bastionName}-PIP')
var PublicIPNoBastion = {
  id: publicIpAddressName.id
}

resource networkInterfaceName 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: networkInterfaceName_var
  location: azureLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: addsPrivateIPAddress
          publicIPAddress: ((!deployBastion) ? PublicIPNoBastion : json('null'))
        }
      }
    ]
  }
}

resource publicIpAddressName 'Microsoft.Network/publicIpAddresses@2021-03-01' = if (!deployBastion) {
  name: publicIpAddressName_var
  location: azureLocation
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Basic'
    tier: 'Regional'
  }
}

resource vmName_resource 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName_var
  location: azureLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName_var}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 1024
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceRef
        }
      ]
    }
    osProfile: {
      computerName: vmName_var
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
  }
}

resource vmName_DeployADDS 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vmName_resource
  name: 'DeployADDS'
  location: azureLocation
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        uri(templateBaseUrl, 'artifacts/SetupADDS.ps1')
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File SetupADDS.ps1 -domainName ${addsDomainName} -domainAdminUsername ${windowsAdminUsername} -domainAdminPassword ${windowsAdminPassword} -templateBaseUrl ${templateBaseUrl}'
    }
  }
}

output scriptfile string = uri(templateBaseUrl, 'artifacts/SetupADDS.ps1')
