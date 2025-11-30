param($Context)

Write-Host "=== Manual Script Test 2 ===" -ForegroundColor Magenta
Write-Host "ループテスト開始"

for ($i = 1; $i -le 3; $i++) {
    Write-Host "  送信 $i 回目..." -ForegroundColor Gray
    Start-Sleep -Milliseconds 500
}

Write-Host "Manual Script Test 2 完了" -ForegroundColor Magenta
