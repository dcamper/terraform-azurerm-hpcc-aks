$command = "kubectl get svc --field-selector metadata.name=eclwatch | Select-Object -Skip 1 | Select-Object -First 1 | ForEach-Object { $_.Split("" "")[3] }"
$IP = (Invoke-Expression $command)

Write-Output "{""ip"": ""${IP}""}"
