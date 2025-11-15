# copy_message_id.ps1
# 受信電文からメッセージIDをコピーして応答電文に転記

param($Context)

# ライブラリ関数を読み込み
. "$PSScriptRoot\..\..\..\..\Modules\OnReceivedLibrary.ps1"

Write-OnReceivedLog "受信電文からメッセージIDをコピーします"

# 受信データからオフセット2、長さ4のバイトを取得（メッセージIDと仮定）
$messageId = Get-ByteSlice -Data $Context.ReceivedData -Offset 2 -Length 4

# 16進数文字列として表示
$messageIdHex = ConvertTo-HexString -Data $messageId
Write-OnReceivedLog "メッセージID: $messageIdHex"

# 応答電文ファイルを読み込み
$responseData = Read-MessageFile -FilePath "response_with_id.csv" -InstancePath $Context.InstancePath

# 応答電文のオフセット4にメッセージIDをコピー
Set-ByteSlice -Target $responseData -Offset 4 -Source $messageId

# 応答電文を送信
Send-MessageData -ConnectionId $Context.ConnectionId -Data $responseData

Write-OnReceivedLog "メッセージID転記完了"
