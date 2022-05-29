param
(
    $ResourceGroup="gearoffcommon-rg",
    $Location="westeurope",
    $NamePrefix="gearoff"
)

az group create --name $ResourceGroup --location $Location --tags purpose=demo | Out-Null
az deployment group create `
  --name "gearoffcommon$([DateTime]::Now.Ticks)"`
  --resource-group "$ResourceGroup" `
  --template-file $PSScriptRoot/common-infra.bicep `
  --parameters `
      namePrefix="$NamePrefix" `
      | Out-Null
