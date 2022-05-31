param location string = resourceGroup().location
param namePrefix string = 'gearoffca'
param serviceBusNamespaceName string = '${namePrefix}sb'
param appStorageAccountName string = '${namePrefix}img'
param serviceBusBlobActionsQueueName string = 'image-actions'
param logAnalyticsName string = '${namePrefix}la'
param appInsightsName string = '${namePrefix}ai'
param containerRegistryName string = 'gearoffcr'
param containerRegistryResourceGroupName string = 'gearoffcommon-rg'
param registryHostname string = '${containerRegistryName}.azurecr.io'
param apiImageName string = '${registryHostname}/client:latest'
param thumbnailerImageName string = '${registryHostname}/image-svc/thumbnailer:latest'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: containerRegistryName
  scope: resourceGroup(containerRegistryResourceGroupName)
}

var containerRegistryPassword = containerRegistry.listCredentials().passwords[0].value

resource thumbNailerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'gearoff-thumbnailer'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      dapr: {
        enabled: true
        appId: 'gearoff-thumbnailer'
        appPort: 80
      }
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'image-thumbnails-storage-connection-string'
          value: appBlobConnectionString
        }
        {
          name: 'acr-password'
          value: containerRegistryPassword
        }
      ]
      registries: [
        {
          server: registryHostname
          username: containerRegistryName
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'thumbnailer'
          image: thumbnailerImageName
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'imageThumbnailsStorageConnectionString'
              secretRef: 'image-thumbnails-storage-connection-string'
            }
          ]
        }
      ]
    }
  }
}

resource apiApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: 'gearoff-api'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id

    configuration: {
      dapr: {
        enabled: true
        appId: 'gearoff-api'
        appPort: 80
      }
      activeRevisionsMode: 'single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      secrets: [
        {
          name: 'image-thumbnails-storage-connection-string'
          value: appBlobConnectionString
        }
        {
          name: 'acr-password'
          value: containerRegistryPassword
        }
      ]
      registries: [
        {
          server: registryHostname
          username: containerRegistryName
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'api'
          image: apiImageName
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'imageUploadStorageConnectionString'
              secretRef: 'image-thumbnails-storage-connection-string'
            }
          ]
        }
      ]
    }
  }
}

resource stateStoreComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: 'statestore'
  parent: containerAppEnvironment
  properties: {
    componentType: 'state.azure.tablestorage'
    version: 'v1'
    metadata: [
      {
        name: 'accountName'
        value: appStorageAccount.name
      }
      {
        name: 'accountKey'
        secretRef: 'state-storage-key'
      }
      {
        name: 'tableName'
        value: 'api-state'
      }
    ]
    secrets: [
      {
        name: 'state-storage-key'
        value: appStorageAccountKey
      }
    ]
    scopes: [
      'gearoff-api'
      'gearoff-thumbnailer'
    ]
  }
}

resource gridQueueMessageComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: 'grid-queue-message'
  parent: containerAppEnvironment
  properties: {
    componentType: 'bindings.azure.storagequeues'
    version: 'v1'
    metadata: [
      {
        name: 'ttlInSeconds'
        value: '60'
      }
      {
        name: 'connectionString'
        secretRef: 'service-bus-connection-string'
      }
      {
        name: 'queueName'
        value: serviceBusBlobActionsQueueName
      }
    ]
    secrets: [
      {
        name: 'service-bus-connection-string'
        value: serviceBusConnectionString
      }
    ]
    scopes: [
      'gearoff-api'
      'gearoff-thumbnailer'
    ]
  }
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: '${namePrefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    daprAIConnectionString: appInsights.properties.ConnectionString
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

var appStorageAccountKey = appStorageAccount.listKeys().keys[0].value
var appBlobConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${appStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${appStorageAccountKey}'
var serviceBusConnectionString = 'Endpoint=sb://${gearoffServiceBusNamespace.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys(serviceBusListKeysEndpoint, '2021-06-01-preview').primaryKey}'
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
