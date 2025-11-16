# NetworkAnalyzer.ps1
# ネットワーク診断モジュール

function Get-NetworkAnalyzerConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionId
    )

    if ([string]::IsNullOrWhiteSpace($ConnectionId)) {
        return $null
    }

    if ($Global:ConnectionService) {
        return $Global:ConnectionService.GetConnection($ConnectionId)
    }

    if (Get-Command Get-ConnectionService -ErrorAction SilentlyContinue) {
        $service = Get-ConnectionService
        return $service.GetConnection($ConnectionId)
    }

    if ($Global:Connections -and $Global:Connections.ContainsKey($ConnectionId)) {
        return $Global:Connections[$ConnectionId]
    }

    return $null
}
function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
    ネットワーク疎通確認（Ping）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetIP,
        
        [Parameter(Mandatory=$false)]
        [int]$Timeout = 1000
    )
    
    Write-Host "[NetworkAnalyzer] Testing connectivity to $TargetIP..." -ForegroundColor Cyan
    
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $result = $ping.Send($TargetIP, $Timeout)
        
        if ($result.Status -eq 'Success') {
            Write-Host "  [?] Ping successful: $($result.RoundtripTime)ms" -ForegroundColor Green
            return [PSCustomObject]@{
                Success = $true
                ResponseTime = $result.RoundtripTime
                Message = "Ping successful"
            }
        } else {
            Write-Warning "  [?] Ping failed: $($result.Status)"
            return [PSCustomObject]@{
                Success = $false
                ResponseTime = 0
                Message = "Ping failed: $($result.Status)"
            }
        }
        
    } catch {
        Write-Error "  [?] Ping error: $_"
        return [PSCustomObject]@{
            Success = $false
            ResponseTime = 0
            Message = "Ping error: $_"
        }
    }
}

function Test-PortConnectivity {
    <#
    .SYNOPSIS
    ポート疎通確認
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetIP,
        
        [Parameter(Mandatory=$true)]
        [int]$Port,
        
        [Parameter(Mandatory=$false)]
        [int]$Timeout = 5000
    )
    
    Write-Host "[NetworkAnalyzer] Testing port connectivity to ${TargetIP}:${Port}..." -ForegroundColor Cyan
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($TargetIP, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($Timeout)
        
        if ($wait) {
            try {
                $tcpClient.EndConnect($asyncResult)
                $tcpClient.Close()
                
                Write-Host "  [?] Port is open" -ForegroundColor Green
                return [PSCustomObject]@{
                    Success = $true
                    Message = "Port is open"
                }
                
            } catch {
                Write-Warning "  [?] Port is closed or filtered"
                return [PSCustomObject]@{
                    Success = $false
                    Message = "Port is closed or filtered"
                }
            }
        } else {
            Write-Warning "  [?] Connection timeout"
            $tcpClient.Close()
            return [PSCustomObject]@{
                Success = $false
                Message = "Connection timeout"
            }
        }
        
    } catch {
        Write-Error "  [?] Port test error: $_"
        return [PSCustomObject]@{
            Success = $false
            Message = "Port test error: $_"
        }
    }
}

function Get-RouteInformation {
    <#
    .SYNOPSIS
    ルーティング情報を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetIP
    )
    
    Write-Host "[NetworkAnalyzer] Getting route information for $TargetIP..." -ForegroundColor Cyan
    
    try {
        # PowerShell 5.1互換のルート取得方法
        $routeOutput = route print | Select-String $TargetIP
        
        if ($routeOutput) {
            Write-Host "  [?] Route found" -ForegroundColor Green
            return [PSCustomObject]@{
                Success = $true
                Message = "Route exists"
                Details = $routeOutput -join "`n"
            }
        } else {
            Write-Warning "  [!] No specific route found (using default gateway)"
            return [PSCustomObject]@{
                Success = $true
                Message = "No specific route (using default)"
                Details = ""
            }
        }
        
    } catch {
        Write-Warning "  [!] Route check error: $_"
        return [PSCustomObject]@{
            Success = $false
            Message = "Route check error"
            Details = ""
        }
    }
}

function Invoke-ComprehensiveDiagnostics {
    <#
    .SYNOPSIS
    包括的な診断を実行
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )
    
    $conn = Get-NetworkAnalyzerConnection -ConnectionId $ConnectionId
    if (-not $conn) {
        throw "Connection not found: $ConnectionId"
    }
    
    Write-Host "`n[NetworkAnalyzer] Running comprehensive diagnostics for $($conn.DisplayName)..." -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    
    $results = @{}
    
    # 接続先情報
    if ($conn.Mode -eq "Client" -or $conn.Mode -eq "Sender") {
        $targetIP = $conn.RemoteIP
        $targetPort = $conn.RemotePort
    } else {
        Write-Host "  [i] Server/Receiver mode - listening on $($conn.LocalIP):$($conn.LocalPort)" -ForegroundColor Gray
        Write-Host "================================================`n" -ForegroundColor Cyan
        
        return [PSCustomObject]@{
            Mode = "Server"
            LocalBinding = "$($conn.LocalIP):$($conn.LocalPort)"
            Recommendations = @("サーバーモードの診断は現在未対応")
        }
    }
    
    # 1. Ping疎通確認
    Write-Host "`n1. Ping Connectivity Test" -ForegroundColor Yellow
    $results['Ping'] = Test-NetworkConnectivity -TargetIP $targetIP
    
    # 2. ポート疎通確認
    Write-Host "`n2. Port Connectivity Test" -ForegroundColor Yellow
    $results['Port'] = Test-PortConnectivity -TargetIP $targetIP -Port $targetPort
    
    # 3. ルーティング確認
    Write-Host "`n3. Route Information" -ForegroundColor Yellow
    $results['Route'] = Get-RouteInformation -TargetIP $targetIP
    
    Write-Host "`n================================================" -ForegroundColor Cyan
    
    # 推奨アクションの生成
    $recommendations = @()
    
    if (-not $results['Ping'].Success) {
        $recommendations += "対象装置（$targetIP）に到達できません。ネットワークケーブル、電源、IPアドレス設定を確認してください。"
    }
    
    if ($results['Ping'].Success -and -not $results['Port'].Success) {
        $recommendations += "ポート${targetPort}が閉じています。対象装置のサービス/アプリケーションが起動しているか確認してください。"
        $recommendations += "ファイアウォール設定でポート${targetPort}が許可されているか確認してください。"
    }
    
    if ($results['Ping'].Success -and $results['Port'].Success) {
        $recommendations += "ネットワーク疎通は正常です。接続エラーが発生する場合は、プロトコル設定やタイムアウト値を確認してください。"
    }
    
    Write-Host "`n[Recommendations]" -ForegroundColor Yellow
    foreach ($rec in $recommendations) {
        Write-Host "  ? $rec" -ForegroundColor Cyan
    }
    Write-Host ""
    
    return [PSCustomObject]@{
        Target = "${targetIP}:${targetPort}"
        PingResult = $results['Ping']
        PortResult = $results['Port']
        RouteResult = $results['Route']
        Recommendations = $recommendations
    }
}

# Export-ModuleMember -Function @(
#     'Test-NetworkConnectivity',
#     'Test-PortConnectivity',
#     'Get-RouteInformation',
#     'Invoke-ComprehensiveDiagnostics'
# )


