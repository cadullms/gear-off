param namePrefix string = 'gearoff'
param serviceBusNamespaceName string = '${namePrefix}sb'
param imageStorageAccountName string = '${namePrefix}img'
param serviceBusBlobActionsQueueName string = 'image-actions'
param location string = resourceGroup().location
param containerAppLogAnalyticsName string = '${namePrefix}la'
param containerRegistryName string = '${namePrefix}cr'

// TODO: Exchange secrets via key vault or switch to (expiremental) output of resource objects themselves
output imageBlobConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${imageStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${imageStorageAccount.listKeys().keys[0].value}'
output serviceBusConnectionString string = 'Endpoint=sb://${gearoffServiceBusNamespace.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys(serviceBusListKeysEndpoint, '2021-06-01-preview').primaryKey}'
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
output logAnalyticsSharedKey string = logAnalytics.listKeys().primarySharedKey
output containerRegistryName string = containerRegistry.name
output containerRegistryPassword string = containerRegistry.listCredentials().passwords[0].value
output stateStorageName string = imageStorageAccount.name
output stateStorageKey string = imageStorageAccount.listKeys().keys[0].value
output containerRegistryId string = containerRegistry.id
output applicationInsightsKey string = appInsights.properties.InstrumentationKey

resource imageStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: imageStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

var serviceBusListKeysEndpoint = '${gearoffServiceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey'
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
    source: imageStorageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource imageBlobActionsEventGridSubscription 'Microsoft.EventGrid/eventSubscriptions@2021-12-01' = {
  name: 'image-blob-actions-subscription'
  scope: imageStorageAccount
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
//        'Microsoft.Storage.BlobDeleted'
      ]
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: containerAppLogAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${namePrefix}ai'
  location: location
  kind: 'web'
  properties:{
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}


resource containerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}
