# UdpCommunication.ps1
# UDP通信処理

function Start-UdpConnection {
    <#
    .SYNOPSIS
    UDP通信を開始
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )
    
    # スレッドで非同期実行
    $scriptBlock = {
        param($connId, $localIP, $localPort, $remoteIP, $remotePort, $mode)
        
        try {
            Write-Host "[UDP] Starting UDP on ${localIP}:${localPort}..." -ForegroundColor Cyan
            
            # 接続オブジェクトを取得
            $conn = $Global:Connections[$connId]
            
            # UDPクライアント作成
            $udpClient = New-Object System.Net.Sockets.UdpClient($localPort)
            
            # リモートエンドポイント設定（送信用）
            if ($remoteIP -and $remotePort -gt 0) {
                $remoteEndPoint = New-Object System.Net.IPEndPoint(
                    [System.Net.IPAddress]::Parse($remoteIP), 
                    $remotePort
                )
            } else {
                $remoteEndPoint = $null
            }
            
            $conn.Socket = $udpClient
            $conn.Status = "CONNECTED"
            
            Write-Host "[UDP] UDP socket ready on ${localIP}:${localPort}" -ForegroundColor Green
            
            # 受信用エンドポイント（任意のアドレスから受信）
            $anyEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            
            # 送受信ループ
            while (-not $conn.CancellationSource.Token.IsCancellationRequested) {
                try {
                    # 送信処理
                    while ($conn.SendQueue.Count -gt 0) {
                        $data = $conn.SendQueue[0]
                        $conn.SendQueue.RemoveAt(0)
                        
                        if ($remoteEndPoint) {
                            # リモートエンドポイント指定済み
                            $bytesSent = $udpClient.Send($data, $data.Length, $remoteEndPoint)
                        } else {
                            # エンドポイント未指定（最後の受信元に送信）
                            if ($conn.Variables.ContainsKey('LastRemoteEndPoint')) {
                                $lastEndPoint = $conn.Variables['LastRemoteEndPoint']
                                $bytesSent = $udpClient.Send($data, $data.Length, $lastEndPoint)
                            } else {
                                Write-Warning "[UDP] No remote endpoint available for sending"
                                continue
                            }
                        }
                        
                        Write-Host "[UDP] Sent $bytesSent bytes" -ForegroundColor Blue
                        $conn.LastActivity = Get-Date
                    }
                    
                    # 受信処理（非ブロッキング）
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
                            
                            # Auto-response processing
                            $rules = Get-ActiveAutoResponseRules -Connection $conn
                            if ($rules -and $rules.Count -gt 0) {
                                try {
                                    Invoke-AutoResponse -ConnectionId $connId -ReceivedData $receivedData -Rules $rules
                                } catch {
                                    Write-Warning "[UDP] Auto-response failed: $_"
                                }
                            }
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
