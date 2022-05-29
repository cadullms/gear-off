param
(
    $ResourceGroup="gearoffwa-rg",
    $Location="westeurope",
    $NamePrefix="gearoffwa"
)

az group create --name $ResourceGroup --location $Location --tags purpose=demo | Out-Null
az deployment group create `
  --name "gearoff$([DateTime]::Now.Ticks)"`
  --resource-group "$ResourceGroup" `
  --template-file $PSScriptRoot/gearoff-web-apps.bicep `
  --parameters `
      namePrefix="$NamePrefix" `
      | Out-Null

