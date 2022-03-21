param location string = resourceGroup().location
param namePrefix string = 'gearoffca'
param apiImageName string = '${namePrefix}cr.azurecr.io/gearoff/api:latest'
param thumbnailerImageName string = '${namePrefix}cr.azurecr.io/gearoff/thumbnailer:latest'
param registryHostname string = '${namePrefix}cr.azurecr.io'

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

// not here yet, see https://github.com/microsoft/azure-container-apps/issues/109
// resource imageGridServiceBusQueueComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
//   name: 'grid-queue-message'
//   parent: containerAppEnvironment

//   properties: {
//     componentType: 'bindings.azure.servicebusqueues'
//     version: 'v1'
//     metadata: [
//       {
//         name: 'connectionString'
//         secretRef: 'connection-string'
//       }
//       {
//         name: 'queueName'
//         value: 'image-actions'
//       }
//       {
//         name: 'ttlInSeconds'
//         value: '60'
//       }
//     ]
//     secrets: [
//       {
//         name: 'connection-string'
//         value: commonInfra.outputs.serviceBusConnectionString
//       }
//     ]
//   }
// }

resource thumbNailerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: 'gearoff-thumbnailer'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'image-thumbnails-storage-connection-string'
          value: commonInfra.outputs.imageBlobConnectionString
        }
        {
          name: 'service-bus-connection-string'
          value: commonInfra.outputs.serviceBusConnectionString
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
        appId: 'gearoff-thumbnailer'
        appPort: 80
        components: [
          {
            name: 'grid-queue-message'
            type: 'bindings.azure.storagequeues'
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
                value: 'image-actions'
              }
            ]
          }
        ]
      }
    }
    scale: {
      minReplicas: 1
      maxReplicas: 1
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
      activeRevisionsMode: 'single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      secrets: [
        {
          name: 'image-thumbnails-storage-connection-string'
          value: commonInfra.outputs.imageBlobConnectionString
        }
        {
          name: 'state-storage-key'
          value: commonInfra.outputs.stateStorageKey
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
        appId: 'gearoff-api'
        appPort: 80
        components: [
          {
            name: 'statestore'
            type: 'state.azure.tablestorage'
            version: 'v1'
            metadata: [
              {
                name: 'accountName'
                value: commonInfra.outputs.stateStorageName
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
          }
        ]
      }
    }
    scale: {
      minReplicas: 1
      maxReplicas: 1
    }
    template: {
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
