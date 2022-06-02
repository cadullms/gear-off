param location string = resourceGroup().location
param namePrefix string = 'gearoffwa'
param serviceBusNamespaceName string = '${namePrefix}sb'
param appStorageAccountName string = '${namePrefix}img'
param serviceBusBlobActionsQueueName string = 'image-actions'
param logAnalyticsName string = '${namePrefix}la'
param appInsightsName string = '${namePrefix}ai'
param containerRegistryName string = 'gearoffcr'
param containerRegistryResourceGroupName string = 'gearoffcommon-rg'
param registryHostname string = '${containerRegistryName}.azurecr.io'
param apiImageName string = '${registryHostname}/client:latest'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: containerRegistryName
  scope: resourceGroup(containerRegistryResourceGroupName)
}

var containerRegistryPassword = containerRegistry.listCredentials().passwords[0].value

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${namePrefix}plan'
  location: location
  sku: {
    name: 'S1'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource apiApp 'Microsoft.Web/sites@2021-03-01' = {
  name: '${namePrefix}app'
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: registryHostname
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistryName
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistryPassword
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DAPR_ENABLED'
          value: 'false'
        }
        {
          name: 'imageUploadStorageConnectionString'
          value: appBlobConnectionString
        }
      ]
      linuxFxVersion: 'DOCKER|${apiImageName}'
    }
  }
}

resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${namePrefix}fstor'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource consumptionPlan 'Microsoft.Web/serverfarms@2020-10-01' = {
  name: '${namePrefix}fplan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource thumbNailerFunction 'Microsoft.Web/sites@2021-03-01' = {
  name: '${namePrefix}thumbnailer'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: consumptionPlan.id
    siteConfig: {
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionStorageAccount.listKeys().keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~3'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'dotnet-isolated'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'gearoffwasb_SERVICEBUS' //TODO: Make this key vault references
          value: serviceBusConnectionString
        }
        {
          name: 'imageThumbnailsStorageConnectionString' //TODO: Make this key vault references
          value: appBlobConnectionString
        }
      ]
    }
  }
}

var appStorageAccountKey = appStorageAccount.listKeys().keys[0].value
var appBlobConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${appStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${appStorageAccountKey}'
resource appStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: appStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

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
