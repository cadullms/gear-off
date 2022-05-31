param location string = resourceGroup().location
param namePrefix string = 'gearoffaks'
param serviceBusNamespaceName string = '${namePrefix}sb'
param appStorageAccountName string = '${namePrefix}img'
param serviceBusBlobActionsQueueName string = 'image-actions'
param logAnalyticsName string = '${namePrefix}la'
param appInsightsName string = '${namePrefix}ai'
param containerRegistryName string = 'gearoffcr'
param containerRegistryResourceGroupName string = 'gearoffcommon-rg'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: containerRegistryName
  scope: resourceGroup(containerRegistryResourceGroupName)
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

resource appStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: appStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource gearoffServiceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource imageActionsServiceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2017-04-01' = {
  name: serviceBusBlobActionsQueueName
  parent: gearoffServiceBusNamespace
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 2048
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P10675199DT2H48M5.4775807S'
    deadLetteringOnMessageExpiration: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
  resource authorizationRule 'authorizationRules' = {
    name: 'manage-rule'
    properties: {
      rights: [
        'Manage'
        'Send'
        'Listen'
      ]
    }
  }
}

resource imageBlobActionsEventGridTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: 'image-blob-actions'
  location: location
  properties: {
    source: appStorageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource imageBlobActionsEventGridSubscription 'Microsoft.EventGrid/eventSubscriptions@2021-12-01' = {
  name: 'image-blob-actions-subscription'
  scope: appStorageAccount
  properties: {
    destination: {
      endpointType: 'ServiceBusQueue'
      properties: {
        resourceId: imageActionsServiceBusQueue.id
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}
