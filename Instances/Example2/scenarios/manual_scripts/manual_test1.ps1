param($Context)

Write-Host "=== Manual Script Test 1 ===" -ForegroundColor Cyan
Write-Host "実行時刻: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "接続ID: $($Context.ConnectionId)" -ForegroundColor Green
Write-Host "インスタンスパス: $($Context.InstancePath)" -ForegroundColor Green

Write-Host "Manual Script Test 1 完了" -ForegroundColor Cyan
