param
(
    $ResourceGroup="gearoffaks-rg",
    $Location="westeurope",
    $NamePrefix="gearoffaks"
)

az group create --name $ResourceGroup --location $Location --tags purpose=demo | Out-Null
az deployment group create `
  --name "gearoffaks$([DateTime]::Now.Ticks)"`
  --resource-group "$ResourceGroup" `
  --template-file $PSScriptRoot/gearoff-aks.bicep `
  --parameters `
      namePrefix="$NamePrefix" `
      | Out-Null

$acrName = "${NamePrefix}cr"
az aks update -g $ResourceGroup -n $NamePrefix --attach-acr $acrName

az aks get-credentials -g $ResourceGroup -n $NamePrefix

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --version 1.4.2 --namespace keda --create-namespace --wait

helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr --version=1.6 --namespace dapr-system --create-namespace --wait

# cert manager
# ingress-nginx