param
(
    $ResourceGroup = "gearoffaca-rg",
    $Location = "westeurope",
    $NamePrefix = "gearoffaca"
)

az group create --name $ResourceGroup --location $Location --tags purpose=demo | Out-Null
az deployment group create `
    --name "gearoff$([DateTime]::Now.Ticks)"`
    --resource-group "$ResourceGroup" `
    --template-file $PSScriptRoot/infra.bicep `
    --parameters `
        namePrefix="$NamePrefix" `
| Out-Null

