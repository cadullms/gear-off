param location string = resourceGroup().location
param namePrefix string = 'gearoffaks'

module commonInfra 'common-infra.bicep' = {
  name: 'common-infra'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

resource gearoffClusterIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'gearoffaks-identity'
  location: location
}

resource gearoffKubeletIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'gearoffaks-kubelet-identity'
  location: location
}

resource gearoffCluster 'Microsoft.ContainerService/managedClusters@2022-01-01' = {
  name: namePrefix
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities:{
      '${gearoffClusterIdentity.id}': {}
    }
  }
  properties: {
    dnsPrefix: '${namePrefix}aks'
    agentPoolProfiles: [
      {
        name: 'default'
        osDiskSizeGB: 128
        count: 1
        vmSize: 'Standard_D2s_v3'
        osType: 'Linux'
        mode: 'System'
      }
    ]
    identityProfile: {
      kubeletIdentities: {
        resourceId: gearoffKubeletIdentity.id
        clientId: gearoffKubeletIdentity.properties.clientId
        objectId: gearoffKubeletIdentity.properties.principalId
      }
    }
    
  }
}
