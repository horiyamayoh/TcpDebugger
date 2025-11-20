# save_data.ps1
# データ要求で受信したデータを保存

param($Context)

. "$PSScriptRoot\..\..\..\..\Core\Domain\OnReceivedLibrary.ps1"

Write-OnReceivedLog "データを保存します"

# 受信データからペイロード部分を抽出（オフセット6以降と仮定）
if ($Context.ReceivedData.Length -gt 6) {
    $payload = Get-ByteSlice -Data $Context.ReceivedData -Offset 6 -Length ($Context.ReceivedData.Length - 6)
    
    # コネクション変数に保存
    Set-ConnectionVariable -Connection $Context.Connection -Name "LastReceivedData" -Value $payload
    
    $hexData = ConvertTo-HexString -Data $payload -Separator " "
    Write-OnReceivedLog "データを保存しました ($($payload.Length) バイト): $hexData"
} else {
    Write-OnReceivedLog "データが短すぎるため保存をスキップしました"
}
