# echo_back.ps1
# 受信したデータをそのままエコーバック

param($Context)

# ライブラリ関数を読み込み
. "$PSScriptRoot\..\..\..\..\Core\Domain\OnReceivedLibrary.ps1"

Write-OnReceivedLog "エコーバックを実行します"

# 受信データをそのまま送信
Send-MessageData -ConnectionId $Context.ConnectionId -Data $Context.ReceivedData

$dataLength = $Context.ReceivedData.Length
Write-OnReceivedLog "エコーバック完了 ($dataLength バイト)"
