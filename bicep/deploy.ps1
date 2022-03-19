param
(
    $ResourceGroup="gearoff-rg",
    $Location="westeurope",
    $NamePrefix="gearoff"
)

az group create --name $ResourceGroup --location $Location | Out-Null
az deployment group create `
  --name "infra$([DateTime]::Now.Ticks)"`
  --resource-group "$ResourceGroup" `
  --template-file $PSScriptRoot/infra.bicep `
  --parameters `
      namePrefix="$NamePrefix" `
      | Out-Null

