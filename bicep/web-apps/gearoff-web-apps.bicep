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

resource appServiceApp 'Microsoft.Web/sites@2021-03-01' = {
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
