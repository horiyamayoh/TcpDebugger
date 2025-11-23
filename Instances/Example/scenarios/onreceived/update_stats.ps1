# update_stats.ps1
# 統計情報を更新

param($Context)

. "$PSScriptRoot\..\..\..\..\Core\Domain\OnReceivedLibrary.ps1"

Write-OnReceivedLog "統計情報を更新します"

# データ要求カウンターをインクリメント
$dataRequestCount = Get-ConnectionVariable -Connection $Context.Connection -Name "DataRequestCount" -Default 0
$dataRequestCount++
Set-ConnectionVariable -Connection $Context.Connection -Name "DataRequestCount" -Value $dataRequestCount

# 受信バイト数を累積
$totalBytesReceived = Get-ConnectionVariable -Connection $Context.Connection -Name "TotalBytesReceived" -Default 0
$totalBytesReceived += $Context.ReceivedData.Length
Set-ConnectionVariable -Connection $Context.Connection -Name "TotalBytesReceived" -Value $totalBytesReceived

Write-OnReceivedLog "統計: データ要求=$dataRequestCount 回, 累計受信=$totalBytesReceived バイト"
