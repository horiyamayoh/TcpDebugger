# ConnectionManager.ps1
# �ڑ��Ǘ����W���[�� - �����ڑ��̈ꌳ�Ǘ�

function Get-ConnectionService {
    if ($Global:ConnectionService) {
        return $Global:ConnectionService
    }
    throw "ConnectionService is not initialized. Please run TcpDebugger.ps1 to bootstrap services."
}

function Get-ManagedConnection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )

    $service = Get-ConnectionService
    $conn = $service.GetConnection($ConnectionId)
    if (-not $conn) {
        throw "Connection not found: $ConnectionId"
    }
    return $conn
}

function New-ConnectionManager {
    <#
    .SYNOPSIS
    �ڑ��}�l�[�W���[��������
    #>
    
    Write-Host "[ConnectionManager] Initializing..." -ForegroundColor Cyan
    
    $service = Get-ConnectionService
    foreach ($conn in @($service.GetAllConnections())) {
        try {
            Stop-Connection -ConnectionId $conn.Id -Force
        } catch {
            Write-Warning "Failed to stop connection $($conn.Id): $_"
        }
    }
    $service.ClearConnections()
    
    Write-Host "[ConnectionManager] Initialized" -ForegroundColor Green
}

function Add-Connection {
    <#
    .SYNOPSIS
    �V�����ڑ���ǉ�
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    $service = Get-ConnectionService
    $conn = $service.AddConnection($Config)
    if (-not $conn) {
        throw "Failed to add connection."
    }
    
    Write-Host "[ConnectionManager] Added connection: $($conn.DisplayName) [$($conn.Id)]" -ForegroundColor Green
    
    return $conn
}

function Remove-Connection {
    <#
    .SYNOPSIS
    �ڑ����폜
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    $service = Get-ConnectionService
    Stop-Connection -ConnectionId $ConnectionId -Force
    $service.RemoveConnection($ConnectionId)
    
    Write-Host "[ConnectionManager] Removed connection: $ConnectionId" -ForegroundColor Yellow
}

function Start-Connection {
    <#
    .SYNOPSIS
    �ڑ����J�n
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    
    if ($conn.Status -eq "CONNECTED" -or $conn.Status -eq "CONNECTING") {
        Write-Warning "[ConnectionManager] Connection already active: $($conn.DisplayName)"
        return
    }
    
    $conn.Status = "CONNECTING"
    $conn.ErrorMessage = $null
    
    Write-Host "[ConnectionManager] Starting connection: $($conn.DisplayName)" -ForegroundColor Cyan
    
    try {
        # ServiceContainer���K�v
        if (-not $Global:ServiceContainer) {
            throw "ServiceContainer is not initialized. Please run TcpDebugger.ps1 first."
        }
        
        # �V�����A�_�v�^�[�A�[�L�e�N�`�����g�p
        switch ($conn.Protocol) {
            "TCP" {
                if ($conn.Mode -eq "Client") {
                    $adapter = $Global:ServiceContainer.Resolve('TcpClientAdapter')
                    $adapter.Start($ConnectionId)
                } elseif ($conn.Mode -eq "Server") {
                    $adapter = $Global:ServiceContainer.Resolve('TcpServerAdapter')
                    $adapter.Start($ConnectionId)
                }
            }
            "UDP" {
                $adapter = $Global:ServiceContainer.Resolve('UdpAdapter')
                $adapter.Start($ConnectionId)
            }
            default {
                throw "Unsupported protocol: $($conn.Protocol)"
            }
        }
        
        $conn.Status = "CONNECTED"
        $conn.LastActivity = Get-Date
        
        $periodicProfilePath = $null
        if ($conn.Variables.ContainsKey('PeriodicSendProfilePath')) {
            $periodicProfilePath = $conn.Variables['PeriodicSendProfilePath']
        }
        
        if ($periodicProfilePath -and (Test-Path -LiteralPath $periodicProfilePath)) {
            try {
                $instancePath = if ($conn.Variables -and $conn.Variables.ContainsKey('InstancePath')) {
                    $conn.Variables['InstancePath']
                } else {
                    $null
                }
                
                if ($instancePath) {
                    Start-PeriodicSend -ConnectionId $ConnectionId -RuleFilePath $periodicProfilePath -InstancePath $instancePath
                }
            } catch {
                Write-Warning "[ConnectionManager] Failed to start periodic send: $_"
            }
        }
        
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
    �ڑ����~
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [switch]$Force
    )
    
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    
    Write-Host "[ConnectionManager] Stopping connection: $($conn.DisplayName)" -ForegroundColor Yellow
    
    try {
        try {
            Stop-PeriodicSend -ConnectionId $ConnectionId
        } catch {
            Write-Verbose "[ConnectionManager] Failed to stop periodic send: $_"
        }
        
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
        
        if ($conn.CancellationSource) {
            $conn.CancellationSource.Cancel()
        }
        
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
        
        if ($conn.Thread -and $conn.Thread.IsAlive) {
            if (-not $Force) {
                $conn.Thread.Join(5000)
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
    �O���[�v���Őڑ��𒊏o
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )
    
    $service = Get-ConnectionService
    return $service.GetConnectionsByGroup($GroupName)
}

function Get-ConnectionsByTag {
    <#
    .SYNOPSIS
    �^�O�Őڑ��𒊏o
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tag
    )
    
    $service = Get-ConnectionService
    return $service.GetConnectionsByTag($Tag)
}

function Get-AllConnections {
    <#
    .SYNOPSIS
    �S�ڑ����擾
    #>
    $service = Get-ConnectionService
    return $service.GetAllConnections()
}

function Send-Data {
    <#
    .SYNOPSIS
    �f�[�^���M
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [byte[]]$Data
    )
    
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    
    if ($conn.Status -ne "CONNECTED") {
        throw "Connection not connected: $($conn.DisplayName)"
    }
    
    [void]$conn.SendQueue.Add($Data)
    Write-Verbose "[ConnectionManager] Data queued for $($conn.DisplayName): $($Data.Length) bytes"
}

