param
(
    $ResourceGroup = "gearoffaks-rg",
    $Location = "westeurope",
    $NamePrefix = "gearoffaks",
    $acrName = "gearoffcr"
)

az group create --name $ResourceGroup --location $Location --tags purpose=demo | Out-Null
az deployment group create `
    --name "gearoffaks$([DateTime]::Now.Ticks)"`
    --resource-group "$ResourceGroup" `
    --template-file $PSScriptRoot/infra.bicep `
    --parameters `
        namePrefix="$NamePrefix" `
| Out-Null

az aks update -g $ResourceGroup -n $NamePrefix --attach-acr $acrName
az aks get-credentials -g $ResourceGroup -n $NamePrefix

helm repo add kedacore https://kedacore.github.io/charts
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install keda kedacore/keda --version 2.6.2 --namespace keda --create-namespace --wait
helm upgrade --install dapr dapr/dapr --version=1.6 --namespace dapr-system --create-namespace --wait

# cert manager
# ingress-nginx