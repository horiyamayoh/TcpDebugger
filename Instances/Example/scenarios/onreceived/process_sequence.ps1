# process_sequence.ps1
# シーケンス番号をインクリメントして応答

param($Context)

# ライブラリ関数を読み込み
. "$PSScriptRoot\..\..\..\..\Core\Domain\OnReceivedLibrary.ps1"

Write-OnReceivedLog "シーケンス番号を処理します"

# コネクション変数からシーケンス番号を取得（初回は0）
$sequence = Get-ConnectionVariable -Connection $Context.Connection -Name "SequenceNumber" -Default 0

# インクリメント
$sequence = ($sequence + 1) % 65536  # 16ビット範囲でループ

# コネクション変数に保存
Set-ConnectionVariable -Connection $Context.Connection -Name "SequenceNumber" -Value $sequence

Write-OnReceivedLog "現在のシーケンス番号: $sequence"

# 応答電文を読み込み
$responseData = Read-MessageFile -FilePath "sequence_response.csv" -InstancePath $Context.InstancePath

# シーケンス番号を2バイト(Big Endian)に変換
$seqBytes = [byte[]]@(
    [byte](($sequence -shr 8) -band 0xFF),
    [byte]($sequence -band 0xFF)
)

# 応答電文のオフセット6にシーケンス番号をセット
Set-ByteSlice -Target $responseData -Offset 6 -Source $seqBytes

# 応答電文を送信
Send-MessageData -ConnectionId $Context.ConnectionId -Data $responseData

Write-OnReceivedLog "シーケンス番号処理完了"
