param namePrefix string = 'gearoff'
param location string = resourceGroup().location
param containerRegistryName string = '${namePrefix}cr'
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

