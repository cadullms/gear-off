param namePrefix string = 'gearoff'
param serviceBusNamespaceName string = '${namePrefix}sb'
param imageStorageAccountName string = '${namePrefix}img'
param serviceBusBlobActionsQueueName string = 'image-actions'
param location string = resourceGroup().location

resource imageStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: imageStorageAccountName
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
        'Microsoft.Storage.BlobDeleted'
      ]
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
  }
}
