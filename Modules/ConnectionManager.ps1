# ConnectionManager.ps1
# 接続管理モジュール - 複数接続の一元管理

# グローバル接続ストア（スレッドセーフ）
if (-not $Global:Connections) {
    $Global:Connections = [System.Collections.Hashtable]::Synchronized(@{})
}

class ConnectionContext {
    [string]$Id
    [string]$Name
    [string]$DisplayName
    [string]$Protocol  # TCP/UDP
    [string]$Mode      # Client/Server/Sender/Receiver
    [string]$LocalIP
    [int]$LocalPort
    [string]$RemoteIP
    [int]$RemotePort
    [string]$Status    # IDLE/CONNECTING/CONNECTED/ERROR/DISCONNECTED
    [object]$Socket    # TcpClient/TcpListener/UdpClient
    [System.Threading.Thread]$Thread
    [System.Threading.CancellationTokenSource]$CancellationSource
    [hashtable]$ScenarioTimers
        $this.ScenarioTimers = [System.Collections.Hashtable]::Synchronized(@{})
    [hashtable]$Variables  # シナリオ変数スコープ
    [System.Collections.ArrayList]$SendQueue
    [System.Collections.ArrayList]$RecvBuffer
    [datetime]$LastActivity
    [string]$ErrorMessage
    [string]$Group
    [string[]]$Tags
    
    ConnectionContext() {
        $this.Variables = [System.Collections.Hashtable]::Synchronized(@{})
        $this.SendQueue = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        $this.RecvBuffer = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        $this.CancellationSource = New-Object System.Threading.CancellationTokenSource
        $this.LastActivity = Get-Date
    }
}

function New-ConnectionManager {
    <#
    .SYNOPSIS
    接続マネージャーを初期化
    #>
    
    Write-Host "[ConnectionManager] Initializing..." -ForegroundColor Cyan
    
    # 既存接続のクリーンアップ
    foreach ($key in $Global:Connections.Keys) {
        try {
            Stop-Connection -ConnectionId $key -Force
        } catch {
            Write-Warning "Failed to stop connection ${key}: $_"
        }
    }
    $Global:Connections.Clear()
    
    Write-Host "[ConnectionManager] Initialized" -ForegroundColor Green
}

function Add-Connection {
    <#
    .SYNOPSIS
    新しい接続を追加
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    $conn = [ConnectionContext]::new()
    
    # ID生成（未指定時は自動生成）
    $conn.Id = if ($Config.Id) { $Config.Id } else { [guid]::NewGuid().ToString() }
    $conn.Name = $Config.Name
    $conn.DisplayName = if ($Config.DisplayName) { $Config.DisplayName } else { $Config.Name }
    $conn.Protocol = $Config.Protocol
    $conn.Mode = $Config.Mode
    $conn.LocalIP = $Config.LocalIP
    $conn.LocalPort = $Config.LocalPort
    $conn.RemoteIP = $Config.RemoteIP
    $conn.RemotePort = $Config.RemotePort
    $conn.Status = "DISCONNECTED"
    $conn.Group = $Config.Group
    $conn.Tags = $Config.Tags
    
    # グローバルストアに追加
    $Global:Connections[$conn.Id] = $conn
    
    Write-Host "[ConnectionManager] Added connection: $($conn.DisplayName) [$($conn.Id)]" -ForegroundColor Green
    
    return $conn
}

function Remove-Connection {
    <#
    .SYNOPSIS
    接続を削除
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    if ($Global:Connections.ContainsKey($ConnectionId)) {
        # 接続停止
        Stop-Connection -ConnectionId $ConnectionId -Force
        
        # ストアから削除
        $Global:Connections.Remove($ConnectionId)
        
        Write-Host "[ConnectionManager] Removed connection: $ConnectionId" -ForegroundColor Yellow
    }
}

function Start-Connection {
    <#
    .SYNOPSIS
    接続を開始
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }
    
    $conn = $Global:Connections[$ConnectionId]
    
    # 既に接続中の場合はスキップ
    if ($conn.Status -eq "CONNECTED" -or $conn.Status -eq "CONNECTING") {
        Write-Warning "[ConnectionManager] Connection already active: $($conn.DisplayName)"
        return
    }
    
    $conn.Status = "CONNECTING"
    $conn.ErrorMessage = $null
    
    Write-Host "[ConnectionManager] Starting connection: $($conn.DisplayName)" -ForegroundColor Cyan
    
    try {
        # プロトコル別に接続処理を呼び出し
        switch ($conn.Protocol) {
            "TCP" {
                if ($conn.Mode -eq "Client") {
                    Start-TcpClientConnection -Connection $conn
                } elseif ($conn.Mode -eq "Server") {
                    Start-TcpServerConnection -Connection $conn
                }
            }
            "UDP" {
                Start-UdpConnection -Connection $conn
            }
            default {
                throw "Unsupported protocol: $($conn.Protocol)"
            }
        }
        
        $conn.Status = "CONNECTED"
        $conn.LastActivity = Get-Date
        
        Write-Host "[ConnectionManager] Connection established: $($conn.DisplayName)" -ForegroundColor Green
        
    } catch {
        $conn.Status = "ERROR"
        $conn.ErrorMessage = $_.Exception.Message
        Write-Error "[ConnectionManager] Failed to start connection $($conn.DisplayName): $_"
    }
}

function Stop-Connection {
    <#
    .SYNOPSIS
        if ($conn.ScenarioTimers -and $conn.ScenarioTimers.Count -gt 0) {
            foreach ($timerState in @($conn.ScenarioTimers.Values)) {
                try {
                    if ($timerState -and $timerState.Timer) {
                        [void]$timerState.Timer.Change([System.Threading.Timeout]::Infinite, [System.Threading.Timeout]::Infinite)
                        $timerState.Timer.Dispose()
                    }
                } catch {
                    Write-Verbose "[ConnectionManager] Failed to dispose timer '$($timerState.Id)': $_"
                }

                try {
                    if ($timerState -and $timerState.CancellationSource) {
                        $timerState.CancellationSource.Cancel()
                        $timerState.CancellationSource.Dispose()
                    }
                } catch {
                    Write-Verbose "[ConnectionManager] Failed to cancel timer '$($timerState.Id)': $_"
                }
            }
            
            $conn.ScenarioTimers.Clear()
        }

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [switch]$Force
    )
    
    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        Write-Warning "Connection not found: $ConnectionId"
        return
    }
    
    $conn = $Global:Connections[$ConnectionId]
    
    Write-Host "[ConnectionManager] Stopping connection: $($conn.DisplayName)" -ForegroundColor Yellow
    
    try {
        # キャンセルトークンを発行
        if ($conn.CancellationSource) {
            $conn.CancellationSource.Cancel()
        }
        
        # ソケットをクローズ
        if ($conn.Socket) {
            if ($conn.Socket -is [System.Net.Sockets.TcpClient]) {
                $conn.Socket.Close()
            } elseif ($conn.Socket -is [System.Net.Sockets.TcpListener]) {
                $conn.Socket.Stop()
            } elseif ($conn.Socket -is [System.Net.Sockets.UdpClient]) {
                $conn.Socket.Close()
            }
            $conn.Socket.Dispose()
            $conn.Socket = $null
        }
        
        # スレッド終了を待機
        if ($conn.Thread -and $conn.Thread.IsAlive) {
            if (-not $Force) {
                $conn.Thread.Join(5000)  # 5秒待機
            }
            if ($conn.Thread.IsAlive) {
                Write-Warning "Thread still alive, forcing abort"
                $conn.Thread.Abort()
            }
        }
        
        $conn.Status = "DISCONNECTED"
        $conn.Thread = $null
        
        Write-Host "[ConnectionManager] Connection stopped: $($conn.DisplayName)" -ForegroundColor Green
        
    } catch {
        Write-Error "[ConnectionManager] Error stopping connection: $_"
    }
}

function Get-ConnectionsByGroup {
    <#
    .SYNOPSIS
    グループ名で接続を抽出
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )
    
    $result = @()
    foreach ($conn in $Global:Connections.Values) {
        if ($conn.Group -eq $GroupName) {
            $result += $conn
        }
    }
    return $result
}

function Get-ConnectionsByTag {
    <#
    .SYNOPSIS
    タグで接続を抽出
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tag
    )
    
    $result = @()
    foreach ($conn in $Global:Connections.Values) {
        if ($conn.Tags -contains $Tag) {
            $result += $conn
        }
    }
    return $result
}

function Get-AllConnections {
    <#
    .SYNOPSIS
    全接続を取得
    #>
    return $Global:Connections.Values
}

function Send-Data {
    <#
    .SYNOPSIS
    データ送信（送信キューに投入）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [byte[]]$Data
    )
    
    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }
    
    $conn = $Global:Connections[$ConnectionId]
    
    if ($conn.Status -ne "CONNECTED") {
        throw "Connection not connected: $($conn.DisplayName)"
    }
    
    # 送信キューに追加
    [void]$conn.SendQueue.Add($Data)
    
    Write-Verbose "[ConnectionManager] Data queued for $($conn.DisplayName): $($Data.Length) bytes"
}

# Export-ModuleMember は Import-Module でのみ有効なため、ドットソース読み込みではコメントアウト
# Export-ModuleMember -Function @(
#     'New-ConnectionManager',
#     'Add-Connection',
#     'Remove-Connection',
#     'Start-Connection',
#     'Stop-Connection',
#     'Get-ConnectionsByGroup',
#     'Get-ConnectionsByTag',
#     'Get-AllConnections',
#     'Send-Data'
# )
