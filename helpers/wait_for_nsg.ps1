param (
    [String]$SUB,
    [String]$RSG
)

while ($true) {
    $command = "az graph query -q ""Resources | project Name=name, SubscriptionID=subscriptionId, ResourceGroupName=resourceGroup, ResourceType=type | where SubscriptionID =~ '${SUB}' and ResourceGroupName =~ '${RSG}' and ResourceType =~ 'microsoft.network/networksecuritygroups'"" --query 'data[0].Name' -o tsv"
    $RES = (Invoke-Expression $command)
    if ("${RES}" -ne "") {
        break
    }
}

Write-Output "{""nsg"": ""${RES}""}"
