# Fix Logger method names in Profile files

$files = @(
    "Core\Domain\ProfileService.ps1",
    "Core\Infrastructure\Repositories\ProfileRepository.ps1"
)

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "Processing: $file"
        $content = Get-Content $fullPath -Raw
        
        $content = $content -replace '\$this\.Logger\.Info\(', '$this.Logger.LogInfo('
        $content = $content -replace '\$this\.Logger\.Error\(', '$this.Logger.LogError('
        $content = $content -replace '\$this\.Logger\.Warning\(', '$this.Logger.LogWarning('
        $content = $content -replace '\$this\.Logger\.Debug\(', '$this.Logger.LogDebug('
        
        Set-Content $fullPath $content -NoNewline
        Write-Host "  [OK] Updated"
    }
}

Write-Host "`nAll files processed successfully" -ForegroundColor Green
