$token = (az account get-access-token --query accessToken -o tsv)
$subscriptionId = (az account show --query id -o tsv)
$resourceGroupName = "gearoff-rg"
$apiVersion = "2022-01-01-preview"
$containerAppName = "gearoff-api"
$url = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.App/containerApps/${containerAppName}?api-version=${apiVersion}"
$result = Invoke-RestMethod -Uri $url -Method GET -Headers @{
    "Authorization"="Bearer ${token}"
}

$result.configuration