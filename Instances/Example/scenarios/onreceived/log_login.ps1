# log_login.ps1
# ログイン要求をログに記録

param($Context)

. "$PSScriptRoot\..\..\..\..\Core\Domain\OnReceivedLibrary.ps1"

Write-OnReceivedLog "ログイン要求を受信しました"

# 受信時刻を記録
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ログインカウンターをインクリメント
$loginCount = Get-ConnectionVariable -Connection $Context.Connection -Name "LoginCount" -Default 0
$loginCount++
Set-ConnectionVariable -Connection $Context.Connection -Name "LoginCount" -Value $loginCount

Write-OnReceivedLog "ログイン回数: $loginCount 回 (最終: $timestamp)"

# 必要に応じてファイルに記録
# $logEntry = "$timestamp - Login received (Count: $loginCount)"
# Add-Content -Path "C:\Logs\login.log" -Value $logEntry
