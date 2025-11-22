# Fix Logger calls - add explicit @{} context parameter

$files = @(
    "Core\Domain\ProfileService.ps1",
    "Core\Infrastructure\Repositories\ProfileRepository.ps1"
)

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "Processing: $file"
        $content = Get-Content $fullPath -Raw
        
        # Fix LogInfo calls - add @{} if missing
        $content = $content -replace '\.LogInfo\("([^"]+)"\)', '.LogInfo("$1", @{})'
        
        # Fix LogWarning calls - add @{} if missing
        $content = $content -replace '\.LogWarning\("([^"]+)"\)', '.LogWarning("$1", @{})'
        
        # Fix LogDebug calls - add @{} if missing
        $content = $content -replace '\.LogDebug\("([^"]+)"\)', '.LogDebug("$1", @{})'
        
        # Fix LogError calls - replace $_ with $_.Exception, @{}
        $content = $content -replace '\.LogError\("([^"]+)", \$_\)', '.LogError("$1", $_.Exception, @{})'
        $content = $content -replace '\.LogError\("([^"]+):\s+\$_"\)', '.LogError("$1: $_", $_.Exception, @{})'
        
        Set-Content $fullPath $content -NoNewline
        Write-Host "  [OK] Updated"
    }
}

Write-Host "`nAll files processed successfully" -ForegroundColor Green
