param location string = resourceGroup().location
param namePrefix string = 'gearoff'
param thumbnailerImageName string = 'gearoffcr.azurecr.io/gearoff/thumbnailer:latest'
param registryHostname string = 'gearoffcr.azurecr.io'

module commonInfra 'common-infra.bicep' = {
  name: 'common-infra'
  params: {
    location: location
    namePrefix: namePrefix
  }
  // TODO: App Insights in common infra
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  name: '${namePrefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: commonInfra.outputs.logAnalyticsCustomerId
        sharedKey: commonInfra.outputs.logAnalyticsSharedKey
      }
    }
  }
}

resource thumbNailerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: 'gearoff-thumbnailer'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      secrets: [
        {
          name: 'image-thumbnails-storage-connection-string'
          value: commonInfra.outputs.imageBlobConnectionString
        }
        {
          name: 'acr-password'
          value: commonInfra.outputs.containerRegistryPassword
        }
      ]
      registries: [
        {
          server: registryHostname
          username: commonInfra.outputs.containerRegistryName
          passwordSecretRef: 'acr-password'
        }
      ]
      dapr: {
        enabled: true
      }
    }
    template: {
      containers: [
        {
          name: 'thumbnailer'
          image: thumbnailerImageName
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
        }
      ]
    }
  }
}
