param
(
    $ResourceGroup="gearoffaks-rg",
    $Location="westeurope",
    $NamePrefix="gearoffaks"
)

$acrName = "${NamePrefix}cr"
$storName = "${NamePrefix}img"
$sbNamespaceName = "${NamePrefix}sb"

az aks get-credentials -g $ResourceGroup -n $NamePrefix

helm upgrade --install gearoff $PSScriptRoot/helm/gearoff --namespace gearoff --create-namespace `
  --set "registry=${acrname}.azurecr.io" `
  --set "serviceBusConnectionString=$(az servicebus namespace authorization-rule keys list -g $ResourceGroup --namespace-name $sbNamespaceName -n RootManageSharedAccessKey --query primaryConnectionString -o tsv)" `
  --set "imageStorageConnectionString=$(az storage account show-connection-string -g $ResourceGroup -n $storName --query connectionString -o tsv)" `
  --set "stateStorage.name=${NamePrefix}img" `
  --set "stateStorage.key=$(az storage account keys list -g $ResourceGroup -n $storName --query [0].value -o tsv)"
