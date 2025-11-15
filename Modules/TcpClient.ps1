# TcpClient.ps1
# TCPクライアント接続処理

function Start-TcpClientConnection {
    <#
    .SYNOPSIS
    TCPクライアント接続を開始
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )
    
    # スレッドで非同期実行
    $scriptBlock = {
        param($connId, $remoteIP, $remotePort)
        
        try {
            Write-Host "[TcpClient] Connecting to ${remoteIP}:${remotePort}..." -ForegroundColor Cyan
            
            # 接続オブジェクトを取得
            $conn = $Global:Connections[$connId]
            
            # TCPクライアント作成
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($remoteIP, $remotePort)
            
            if ($tcpClient.Connected) {
                $conn.Socket = $tcpClient
                $conn.Status = "CONNECTED"
                
                Write-Host "[TcpClient] Connected to ${remoteIP}:${remotePort}" -ForegroundColor Green
                
                # ストリーム取得
                $stream = $tcpClient.GetStream()
                $buffer = New-Object byte[] 8192
                
                # 送受信ループ
                while ($tcpClient.Connected -and -not $conn.CancellationSource.Token.IsCancellationRequested) {
                    try {
                        # 送信処理
                        while ($conn.SendQueue.Count -gt 0) {
                            $data = $conn.SendQueue[0]
                            $conn.SendQueue.RemoveAt(0)
                            
                            $stream.Write($data, 0, $data.Length)
                            $stream.Flush()
                            
                            Write-Host "[TcpClient] Sent $($data.Length) bytes" -ForegroundColor Blue
                            $conn.LastActivity = Get-Date
                        }
                        

                                $rules = Get-ActiveAutoResponseRules -Connection $conn
                                if ($rules -and $rules.Count -gt 0) {
                                    try {
                                        Invoke-AutoResponse -ConnectionId $connId -ReceivedData $receivedData -Rules $rules
                                    } catch {
                                        Write-Warning "[TcpClient] Auto-response failed: $_"
                                    }
                                }
                        # 受信処理（非ブロッキング）
                        if ($stream.DataAvailable) {
                            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
                            
                            if ($bytesRead -gt 0) {
                                $receivedData = $buffer[0..($bytesRead-1)]
                                
                                # 受信バッファに追加
                                [void]$conn.RecvBuffer.Add([PSCustomObject]@{
                                    Timestamp = Get-Date
                                    Data = $receivedData
                                    Length = $bytesRead
                                })
                                
                                Write-Host "[TcpClient] Received $bytesRead bytes" -ForegroundColor Magenta
                                $conn.LastActivity = Get-Date
                            }
                        }
                        
                        # CPU負荷軽減
                        Start-Sleep -Milliseconds 10
                        
                    } catch {
                        if (-not $conn.CancellationSource.Token.IsCancellationRequested) {
                            Write-Error "[TcpClient] Error in loop: $_"
                        }
                        break
                    }
                }
                
            } else {
                throw "Failed to connect"
            }
            
        } catch {
            $conn = $Global:Connections[$connId]
            $conn.Status = "ERROR"
            $conn.ErrorMessage = $_.Exception.Message
            Write-Error "[TcpClient] Connection error: $_"
            
        } finally {
            # クリーンアップ
            if ($tcpClient) {
                $tcpClient.Close()
                $tcpClient.Dispose()
            }
            
            $conn = $Global:Connections[$connId]
            if ($conn.Status -ne "ERROR") {
                $conn.Status = "DISCONNECTED"
            }
            $conn.Socket = $null
            
            Write-Host "[TcpClient] Connection closed" -ForegroundColor Yellow
        }
    }
    
    # スレッド開始
    $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
        & $scriptBlock -connId $Connection.Id -remoteIP $Connection.RemoteIP -remotePort $Connection.RemotePort
    })
    
    $Connection.Thread = $thread
    $thread.IsBackground = $true
    $thread.Start()
}

# Export-ModuleMember -Function 'Start-TcpClientConnection'
