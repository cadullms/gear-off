param location string = resourceGroup().location
param namePrefix string = 'gearoffwa'
param apiImageName string = '${namePrefix}cr.azurecr.io/gearoff/api:latest'
param thumbnailerImageName string = '${namePrefix}cr.azurecr.io/gearoff/thumbnailer:latest'
param registryHostname string = '${namePrefix}cr.azurecr.io'

module commonInfra '../common-infra.bicep' = {
  name: 'common-infra'
  params: {
    location: location
    namePrefix: namePrefix
  }
  // TODO: App Insights in common infra
}

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
          value: commonInfra.outputs.containerRegistryName
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: commonInfra.outputs.containerRegistryPassword
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
          value: commonInfra.outputs.imageBlobConnectionString
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
          'value': commonInfra.outputs.applicationInsightsKey
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
          value: commonInfra.outputs.serviceBusConnectionString
        }
        {
          name: 'imageThumbnailsStorageConnectionString' //TODO: Make this key vault references
          value: commonInfra.outputs.imageBlobConnectionString
        }
      ]
    }
  }
}
