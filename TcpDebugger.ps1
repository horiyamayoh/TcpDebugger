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

# WinForms例外モードを設定（既にコントロールが作成されている場合は無視）
Add-Type -AssemblyName System.Windows.Forms
try {
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
}
catch {
    # コントロールが既に作成されている場合はスキップ（実害なし）
}

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
    "Core\Domain\ConnectionManager.ps1",
    "Core\Domain\ReceivedRuleEngine.ps1",
    "Core\Domain\OnReceivedLibrary.ps1",
    "Core\Domain\ProfileModels.ps1",
    "Core\Domain\ProfileService.ps1",
    "Core\Infrastructure\Repositories\RuleRepository.ps1",
    "Core\Infrastructure\Repositories\InstanceRepository.ps1",
    "Core\Infrastructure\Repositories\ProfileRepository.ps1",
    "Core\Domain\RuleProcessor.ps1",
    "Core\Domain\ReceivedEventPipeline.ps1",
    "Core\Domain\MessageService.ps1",
    "Core\Domain\RunspaceMessages.ps1",
    "Core\Infrastructure\ServiceContainer.ps1",
    "Core\Infrastructure\RunspaceMessageQueue.ps1",
    "Core\Infrastructure\RunspaceMessageProcessor.ps1",
    "Core\Infrastructure\Adapters\TcpClientAdapter.ps1",
    "Core\Infrastructure\Adapters\TcpServerAdapter.ps1",
    "Core\Infrastructure\Adapters\UdpAdapter.ps1",
    "Core\Application\InstanceManager.ps1",
    "Core\Application\NetworkAnalyzer.ps1"
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

# 設定ファイル読み込み
$configPath = Join-Path $script:RootPath "Config\defaults.psd1"
$config = if (Test-Path -LiteralPath $configPath) {
    Import-PowerShellDataFile -Path $configPath
} else {
    @{ 
        EnableFileLogging = $true
        LogBufferSize = 50
        LogFlushIntervalSeconds = 5
        EnableDebugOutput = $true
    }
}

# グローバル設定をスクリプトスコープに保存
$script:EnableDebugOutput = if ($null -ne $config.EnableDebugOutput) { $config.EnableDebugOutput } else { $true }

$logPath = Join-Path $logDirectory "TcpDebugger.log"
$script:Logger = New-FileLogger -Path $logPath -Name "TcpDebugger" `
    -BufferSize $config.LogBufferSize `
    -FlushIntervalSeconds $config.LogFlushIntervalSeconds `
    -Enabled $config.EnableFileLogging
$script:ErrorHandler = [ErrorHandler]::new($script:Logger)
$Global:Connections = if ($Global:Connections) { $Global:Connections } else { [System.Collections.Hashtable]::Synchronized(@{}) }

# グローバル例外ハンドラー設定
[System.AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $eventArgs)
    $exception = $eventArgs.ExceptionObject
    $script:Logger.LogError("Unhandled exception in AppDomain", $exception, @{
        IsTerminating = $eventArgs.IsTerminating
    })
    Write-Host "[FATAL] Unhandled exception: $($exception.Message)" -ForegroundColor Red
    Write-Host $exception.StackTrace -ForegroundColor Red
})

# WinFormsスレッド例外ハンドラー
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $eventArgs)
    $exception = $eventArgs.Exception
    $script:Logger.LogError("Unhandled thread exception", $exception, @{})
    Write-Host "[ERROR] Thread exception: $($exception.Message)" -ForegroundColor Red
    Write-Host $exception.StackTrace -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show(
        "An unexpected error occurred:`n`n$($exception.Message)`n`nSee log file for details.",
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
})

$script:ServiceContainer = New-ServiceContainer
$Global:ServiceContainer = $script:ServiceContainer
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
$script:ServiceContainer.RegisterSingleton('ProfileRepository', {
    param($c)
    [ProfileRepository]::new($script:Logger)
})
$script:ServiceContainer.RegisterSingleton('ProfileService', {
    param($c)
    $profileRepository = $c.Resolve('ProfileRepository')
    $logger = $c.Resolve('Logger')
    [ProfileService]::new($profileRepository, $logger)
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

# Runspace通信基盤の登録
$script:ServiceContainer.RegisterSingleton('RunspaceMessageQueue', {
    param($c)
    $logger = $c.Resolve('Logger')
    [RunspaceMessageQueue]::new($logger)
})

$script:ServiceContainer.RegisterSingleton('MessageProcessor', {
    param($c)
    $queue = $c.Resolve('RunspaceMessageQueue')
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    [RunspaceMessageProcessor]::new($queue, $connectionService, $pipeline, $logger)
})

# 通信アダプターの登録（Transient: 必要時に新規インスタンス生成）
$script:ServiceContainer.RegisterTransient('TcpClientAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    $messageQueue = $c.Resolve('RunspaceMessageQueue')
    [TcpClientAdapter]::new($connectionService, $pipeline, $logger, $messageQueue)
})

$script:ServiceContainer.RegisterTransient('TcpServerAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    $messageQueue = $c.Resolve('RunspaceMessageQueue')
    [TcpServerAdapter]::new($connectionService, $pipeline, $logger, $messageQueue)
})

$script:ServiceContainer.RegisterTransient('UdpAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    $messageQueue = $c.Resolve('RunspaceMessageQueue')
    [UdpAdapter]::new($connectionService, $pipeline, $logger, $messageQueue)
})

$Global:ConnectionService = $script:ServiceContainer.Resolve('ConnectionService')
$Global:RuleRepository = $script:ServiceContainer.Resolve('RuleRepository')
$Global:InstanceRepository = $script:ServiceContainer.Resolve('InstanceRepository')
$Global:ProfileRepository = $script:ServiceContainer.Resolve('ProfileRepository')
$Global:ProfileService = $script:ServiceContainer.Resolve('ProfileService')
$Global:ReceivedEventPipeline = $script:ServiceContainer.Resolve('ReceivedEventPipeline')
$Global:MessageService = $script:ServiceContainer.Resolve('MessageService')
$Global:MessageProcessor = $script:ServiceContainer.Resolve('MessageProcessor')
$Global:RunspaceMessageQueue = $script:ServiceContainer.Resolve('RunspaceMessageQueue')

Write-Host "[Init] Loading modules..." -ForegroundColor Cyan

# UIモジュールをインポート
$uiPath = Join-Path $script:RootPath "Presentation\UI"

# ViewBuilderを先に読み込む
$viewBuilderFile = Join-Path $uiPath "ViewBuilder.ps1"
if (Test-Path $viewBuilderFile) {
    . $viewBuilderFile
    Write-Host "  [+] ViewBuilder.ps1" -ForegroundColor Green
} else {
    Write-Error "ViewBuilder module not found: $viewBuilderFile"
    exit 1
}

# MainFormを読み込む
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
    
    # インスタンスプロファイルを読み込み
    Write-Host "[Init] Loading instance profiles..." -ForegroundColor Cyan
    foreach ($instance in $instances) {
        try {
            $Global:ProfileService.LoadInstanceProfiles($instance.FolderName, $instance.FolderPath)
            $loadedCount = $Global:ProfileService.GetAvailableInstanceProfiles($instance.FolderName).Count
            Write-Host "  [+] Loaded $loadedCount profiles for: $($instance.FolderName)" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to load profiles for $($instance.FolderName): $_"
        }
    }
    
    # アプリケーションプロファイルを読み込み
    Write-Host "[Init] Loading application profiles..." -ForegroundColor Cyan
    $appProfilePath = Join-Path (Join-Path $script:RootPath "Config") "app_profile.csv"
    if (Test-Path $appProfilePath) {
        try {
            $instanceNames = $instances | ForEach-Object { $_.FolderName }
            $Global:ProfileService.LoadApplicationProfiles($appProfilePath, $instanceNames)
            Write-Host "  [+] Loaded application profiles" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to load application profiles: $_"
        }
    } else {
        Write-Warning "Application profile file not found: $appProfilePath"
    }
    
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





