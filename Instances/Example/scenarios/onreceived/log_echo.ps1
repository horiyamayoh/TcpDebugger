# log_echo.ps1
# エコー要求をログに記録

param($Context)

. "$PSScriptRoot\..\..\..\..\Core\Domain\OnReceivedLibrary.ps1"

Write-OnReceivedLog "エコー要求を受信しました"

$hexData = ConvertTo-HexString -Data $Context.ReceivedData -Separator " "
Write-OnReceivedLog "エコーデータ: $hexData"

# エコーカウンターをインクリメント
$echoCount = Get-ConnectionVariable -Connection $Context.Connection -Name "EchoCount" -Default 0
$echoCount++
Set-ConnectionVariable -Connection $Context.Connection -Name "EchoCount" -Value $echoCount

Write-OnReceivedLog "エコー回数: $echoCount 回"
