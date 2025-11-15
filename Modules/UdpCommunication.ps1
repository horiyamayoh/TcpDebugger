# UdpCommunication.ps1
# UDP connection handling

function Start-UdpConnection {
    <#
    .SYNOPSIS
    Starts a UDP communication worker
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )
    
    # Run work on background thread
    $scriptBlock = {
        param($conn)

        if (-not $conn) {
            return
        }

        try {
            Write-Host "[UDP] Starting UDP on ${($conn.LocalIP)}:${($conn.LocalPort)}..." -ForegroundColor Cyan

            $udpClient = New-Object System.Net.Sockets.UdpClient($conn.LocalPort)

            # MݒiIvVj
            if ($conn.RemoteIP -and $conn.RemotePort -gt 0) {
                    [System.Net.IPAddress]::Parse($conn.RemoteIP),
                    $conn.RemotePort


            Write-Host "[UDP] UDP socket ready on ${($conn.LocalIP)}:${($conn.LocalPort)}" -ForegroundColor Green

            # MpGh|Cg

            while ($conn.CancellationSource -and -not $conn.CancellationSource.Token.IsCancellationRequested) {



                    # M





                    if (-not ($conn.CancellationSource -and $conn.CancellationSource.Token.IsCancellationRequested)) {

            if ($conn) {
                $conn.Status = "ERROR"
                $conn.ErrorMessage = $_.Exception.Message
            }


            if ($conn) {
                if ($conn.Status -ne "ERROR") {
                    $conn.Status = "DISCONNECTED"
                }
                $conn.Socket = $null


        & $scriptBlock $Connection
                    if ($udpClient.Available -gt 0) {
                        $receivedData = $udpClient.Receive([ref]$anyEndPoint)
                        
                        if ($receivedData.Length -gt 0) {
                            # 受信バッファに追加
                            [void]$conn.RecvBuffer.Add([PSCustomObject]@{
                                Timestamp = Get-Date
                                Data = $receivedData
                                Length = $receivedData.Length
                                RemoteEndPoint = $anyEndPoint.ToString()
                            })
                            
                            # 最後の受信元を記録
                            $conn.Variables['LastRemoteEndPoint'] = $anyEndPoint
                            
                            Write-Host "[UDP] Received $($receivedData.Length) bytes from $anyEndPoint" -ForegroundColor Magenta
                            $conn.LastActivity = Get-Date
                        }
                    }
                    
                    # CPU負荷軽減
                    Start-Sleep -Milliseconds 10
                    
                } catch {
                    if (-not $conn.CancellationSource.Token.IsCancellationRequested) {
                        Write-Error "[UDP] Error in loop: $_"
                    }
                    break
                }
            }
            
        } catch {
            $conn = $Global:Connections[$connId]
            $conn.Status = "ERROR"
            $conn.ErrorMessage = $_.Exception.Message
            Write-Error "[UDP] Socket error: $_"
            
        } finally {
            # クリーンアップ
            if ($udpClient) {
                $udpClient.Close()
                $udpClient.Dispose()
            }
            
            $conn = $Global:Connections[$connId]
            if ($conn.Status -ne "ERROR") {
                $conn.Status = "DISCONNECTED"
            }
            $conn.Socket = $null
            
            Write-Host "[UDP] Socket closed" -ForegroundColor Yellow
        }
    }
    
    # スレッド開始
    $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
        & $scriptBlock -connId $Connection.Id `
                       -localIP $Connection.LocalIP `
                       -localPort $Connection.LocalPort `
                       -remoteIP $Connection.RemoteIP `
                       -remotePort $Connection.RemotePort `
                       -mode $Connection.Mode
    })
    
    $Connection.Thread = $thread
    $thread.IsBackground = $true
    $thread.Start()
}

# Export-ModuleMember -Function 'Start-UdpConnection'
