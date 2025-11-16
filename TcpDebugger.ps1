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
$script:CurrentMainForm = $null
$script:ConsoleCancelHandler = $null

# モジュールのインポート
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TCP Test Controller v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[Init] Loading core components..." -ForegroundColor Cyan

$coreModules = @(
    "Core\Common\Logger.ps1",
    "Core\Common\ErrorHandler.ps1",
    "Core\Common\ThreadSafeCollections.ps1",
    "Core\Domain\VariableScope.ps1",
    "Core\Domain\ConnectionModels.ps1",
    "Core\Domain\ConnectionService.ps1",
    "Core\Infrastructure\Repositories\RuleRepository.ps1",
    "Core\Infrastructure\Repositories\InstanceRepository.ps1",
    "Core\Domain\RuleProcessor.ps1",
    "Core\Domain\ReceivedEventPipeline.ps1",
    "Core\Domain\MessageService.ps1",
    "Core\Infrastructure\ServiceContainer.ps1",
    "Core\Infrastructure\Adapters\TcpClientAdapter.ps1",
    "Core\Infrastructure\Adapters\TcpServerAdapter.ps1",
    "Core\Infrastructure\Adapters\UdpAdapter.ps1"
)

foreach ($coreModule in $coreModules) {
    $corePath = Join-Path $script:RootPath $coreModule
    if (Test-Path -LiteralPath $corePath) {
        . $corePath
        Write-Host "  [+] $coreModule" -ForegroundColor Green
    } else {
        Write-Warning "  [!] Core module not found: $coreModule"
    }
}

$logDirectory = Join-Path $script:RootPath "Logs"
if (-not (Test-Path -LiteralPath $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

$logPath = Join-Path $logDirectory "TcpDebugger.log"
$script:Logger = New-FileLogger -Path $logPath -Name "TcpDebugger"
$script:ErrorHandler = [ErrorHandler]::new($script:Logger)
$Global:Connections = if ($Global:Connections) { $Global:Connections } else { [System.Collections.Hashtable]::Synchronized(@{}) }

$script:ServiceContainer = New-ServiceContainer
$script:ServiceContainer.RegisterSingleton('Logger', { param($c) $script:Logger })
$script:ServiceContainer.RegisterSingleton('ConnectionService', {
    param($c)
    [ConnectionService]::new($script:Logger, $Global:Connections)
})
$script:ServiceContainer.RegisterSingleton('RuleRepository', {
    param($c)
    [RuleRepository]::new($script:Logger)
})
$script:ServiceContainer.RegisterSingleton('InstanceRepository', {
    param($c)
    [InstanceRepository]::new($script:Logger)
})
$script:ServiceContainer.RegisterSingleton('RuleProcessor', {
    param($c)
    $logger = $c.Resolve('Logger')
    $ruleRepository = $c.Resolve('RuleRepository')
    [RuleProcessor]::new($logger, $ruleRepository)
})
$script:ServiceContainer.RegisterSingleton('ReceivedEventPipeline', {
    param($c)
    $logger = $c.Resolve('Logger')
    $connectionService = $c.Resolve('ConnectionService')
    $ruleProcessor = $c.Resolve('RuleProcessor')
    [ReceivedEventPipeline]::new($logger, $connectionService, $ruleProcessor)
})
$script:ServiceContainer.RegisterSingleton('MessageService', {
    param($c)
    $logger = $c.Resolve('Logger')
    $connectionService = $c.Resolve('ConnectionService')
    [MessageService]::new($logger, $connectionService)
})

# 通信アダプターの登録（Transient: 必要時に新規インスタンス生成）
$script:ServiceContainer.RegisterTransient('TcpClientAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    [TcpClientAdapter]::new($connectionService, $pipeline, $logger)
})

$script:ServiceContainer.RegisterTransient('TcpServerAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    [TcpServerAdapter]::new($connectionService, $pipeline, $logger)
})

$script:ServiceContainer.RegisterTransient('UdpAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    [UdpAdapter]::new($connectionService, $pipeline, $logger)
})

$Global:ConnectionService = $script:ServiceContainer.Resolve('ConnectionService')
$Global:RuleRepository = $script:ServiceContainer.Resolve('RuleRepository')
$Global:InstanceRepository = $script:ServiceContainer.Resolve('InstanceRepository')
$Global:ReceivedEventPipeline = $script:ServiceContainer.Resolve('ReceivedEventPipeline')
$Global:MessageService = $script:ServiceContainer.Resolve('MessageService')

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
    "ReceivedRuleEngine.ps1",
    "OnReceivedHandler.ps1",
    "OnReceivedLibrary.ps1",
    "PeriodicSender.ps1",
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

# Ctrl+C (ConsoleCancel) handler to ensure the GUI can be closed from the console
try {
    $script:ConsoleCancelHandler = [System.ConsoleCancelEventHandler]{
        param($sender, $eventArgs)

        $eventArgs.Cancel = $true

        Write-Host ""
        Write-Host "[Ctrl+C] Shutdown requested. Attempting graceful shutdown..." -ForegroundColor Yellow

        $form = $script:CurrentMainForm
        if ($form -and -not $form.IsDisposed) {
            try {
                $null = $form.BeginInvoke([System.Action]{
                    if ($script:CurrentMainForm -and -not $script:CurrentMainForm.IsDisposed) {
                        $script:CurrentMainForm.Close()
                    }
                })
                return
            } catch {
                # Fall through to forced exit
            }
        }

        Write-Warning "GUI not available. Forcing process exit."
        [System.Environment]::Exit(0)
    }

    [Console]::add_CancelKeyPress($script:ConsoleCancelHandler)
} catch {
    Write-Warning "Failed to register Ctrl+C handler: $_"
}

# GUIを表示
Write-Host "[GUI] Starting GUI..." -ForegroundColor Cyan
try {
    Show-MainForm
} finally {
    if ($script:ConsoleCancelHandler) {
        [Console]::remove_CancelKeyPress($script:ConsoleCancelHandler)
        $script:ConsoleCancelHandler = $null
    }
}

# 終了時のクリーンアップ
Write-Host ""
Write-Host "[Cleanup] Shutting down..." -ForegroundColor Yellow

try {
    $cleanupService = if ($Global:ConnectionService) { $Global:ConnectionService } elseif (Get-Command Get-ConnectionService -ErrorAction SilentlyContinue) { Get-ConnectionService } else { $null }
    if ($cleanupService) {
        foreach ($conn in $cleanupService.GetAllConnections()) {
            try {
                Stop-Connection -ConnectionId $conn.Id -Force
            } catch {
                # ignore errors
            }
        }
    } else {
        foreach ($connId in $Global:Connections.Keys) {
            try {
                Stop-Connection -ConnectionId $connId -Force
            } catch {
                # ignore errors
            }
        }
    }
} catch {
    # ignore cleanup errors
}


Write-Host "[Cleanup] Shutdown completed" -ForegroundColor Green
Write-Host ""
Write-Host "Thank you for using TCP Test Controller!" -ForegroundColor Cyan





