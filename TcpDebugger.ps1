# TcpDebugger.ps1
# TCP/IP 試験装置 メインスクリプト

<#
.SYNOPSIS
TCP/IP通信のテスト・デバッグを行うための試験装置

.DESCRIPTION
設定ファイルベースでシナリオ実行が可能で、視覚的に接続状態を確認できるGUIを備えた
TCP/UDP通信試験ツール

.NOTES
Version: 1.0.0
Author: TcpDebugger Project
Requires: PowerShell 5.1+, .NET Framework (Windows標準)
#>

# スクリプトのルートパスを取得
$script:RootPath = $PSScriptRoot

# モジュールのインポート
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TCP Test Controller v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[Init] Loading modules..." -ForegroundColor Cyan

# 全モジュールをインポート
$modulePath = Join-Path $script:RootPath "Modules"
$modules = @(
    "ConnectionManager.ps1",
    "TcpClient.ps1",
    "TcpServer.ps1",
    "UdpCommunication.ps1",
    "MessageHandler.ps1",
    "ScenarioEngine.ps1",
    "AutoResponse.ps1",
    "QuickSender.ps1",
    "InstanceManager.ps1",
    "NetworkAnalyzer.ps1"
)

foreach ($module in $modules) {
    $moduleFile = Join-Path $modulePath $module
    if (Test-Path $moduleFile) {
        . $moduleFile
        Write-Host "  [+] $module" -ForegroundColor Green
    } else {
        Write-Warning "  [!] Module not found: $module"
    }
}

# UIモジュールをインポート
$uiPath = Join-Path $script:RootPath "UI"
$uiFile = Join-Path $uiPath "MainForm.ps1"
if (Test-Path $uiFile) {
    . $uiFile
    Write-Host "  [+] MainForm.ps1" -ForegroundColor Green
} else {
    Write-Error "UI module not found: $uiFile"
    exit 1
}

Write-Host ""

# 接続マネージャー初期化
New-ConnectionManager

# インスタンスフォルダをスキャン
$instancesPath = Join-Path $script:RootPath "Instances"
Write-Host "[Init] Scanning instance folders..." -ForegroundColor Cyan

$instances = Find-InstanceFolders -InstancesPath $instancesPath

if ($instances.Count -eq 0) {
    Write-Warning "No instances found in $instancesPath"
    Write-Host "Please create instance folders with instance.psd1 configuration files." -ForegroundColor Yellow
} else {
    # インスタンスから接続を初期化
    Initialize-InstanceConnections -Instances $instances
    
    # AutoStart接続を開始
    Start-AutoStartConnections -Instances $instances
}

Write-Host ""
Write-Host "[Init] Initialization completed!" -ForegroundColor Green
Write-Host ""

# GUIを表示
Write-Host "[GUI] Starting GUI..." -ForegroundColor Cyan
Show-MainForm

# 終了時のクリーンアップ
Write-Host ""
Write-Host "[Cleanup] Shutting down..." -ForegroundColor Yellow

foreach ($connId in $Global:Connections.Keys) {
    try {
        Stop-Connection -ConnectionId $connId -Force
    } catch {
        # エラーは無視
    }
}

Write-Host "[Cleanup] Shutdown completed" -ForegroundColor Green
Write-Host ""
Write-Host "Thank you for using TCP Test Controller!" -ForegroundColor Cyan
