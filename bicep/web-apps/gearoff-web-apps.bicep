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
