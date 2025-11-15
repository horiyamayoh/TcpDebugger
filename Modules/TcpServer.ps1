# TcpServer.ps1
# TCPサーバー接続処理

function Start-TcpServerConnection {
    <#
    .SYNOPSIS
    TCPサーバーを起動
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )
    
    # スレッドで非同期実行
    $scriptBlock = {
        param($connId, $localIP, $localPort)
        
        try {
            Write-Host "[TcpServer] Starting server on ${localIP}:${localPort}..." -ForegroundColor Cyan
            
            # 接続オブジェクトを取得
            $conn = $Global:Connections[$connId]
            
            # TCPリスナー作成
            $ipAddress = [System.Net.IPAddress]::Parse($localIP)
            $listener = New-Object System.Net.Sockets.TcpListener($ipAddress, $localPort)
            $listener.Start()
            
            $conn.Socket = $listener
            $conn.Status = "CONNECTED"
            
            Write-Host "[TcpServer] Server listening on ${localIP}:${localPort}" -ForegroundColor Green
            
            # クライアント接続待機（非ブロッキング）
            $client = $null
            $stream = $null
            
            while (-not $conn.CancellationSource.Token.IsCancellationRequested) {
                try {
                    # 接続待機（ポーリング方式）
                    if ($listener.Pending()) {
                        # 既存クライアントがあればクローズ
                        if ($client) {
                            $client.Close()
                        }
                        
                        $client = $listener.AcceptTcpClient()
                        $stream = $client.GetStream()
                        
                        $remoteEndpoint = $client.Client.RemoteEndPoint
                        Write-Host "[TcpServer] Client connected: $remoteEndpoint" -ForegroundColor Green
                    }
                    
                    # クライアントが接続中の場合、送受信処理
                    if ($client -and $client.Connected) {
                        # 送信処理
                        while ($conn.SendQueue.Count -gt 0) {
                            $data = $conn.SendQueue[0]
                            $conn.SendQueue.RemoveAt(0)
                            
                            $stream.Write($data, 0, $data.Length)
                            $stream.Flush()
                            
                            Write-Host "[TcpServer] Sent $($data.Length) bytes" -ForegroundColor Blue
                            $conn.LastActivity = Get-Date
                        }
                        
                        # 受信処理
                        if ($stream.DataAvailable) {
                            $buffer = New-Object byte[] 8192
                            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
                            
                            if ($bytesRead -gt 0) {
                                $receivedData = $buffer[0..($bytesRead-1)]
                                
                                # 受信バッファに追加
                                [void]$conn.RecvBuffer.Add([PSCustomObject]@{
                                    Timestamp = Get-Date
                                    Data = $receivedData
                                    Length = $bytesRead
                                })
                                
                                Write-Host "[TcpServer] Received $bytesRead bytes" -ForegroundColor Magenta
                                $conn.LastActivity = Get-Date

                                $rules = Get-ActiveAutoResponseRules -Connection $conn
                                if ($rules -and $rules.Count -gt 0) {
                                    try {
                                        Invoke-AutoResponse -ConnectionId $connId -ReceivedData $receivedData -Rules $rules
                                    } catch {
                                        Write-Warning "[TcpServer] Auto-response failed: $_"
                                    }
                                }
                            }
                        }
                    }
                    
                    # CPU負荷軽減
                    Start-Sleep -Milliseconds 10
                    
                } catch {
                    if (-not $conn.CancellationSource.Token.IsCancellationRequested) {
                        Write-Error "[TcpServer] Error in loop: $_"
                    }
                }
            }
            
        } catch {
            $conn = $Global:Connections[$connId]
            $conn.Status = "ERROR"
            $conn.ErrorMessage = $_.Exception.Message
            Write-Error "[TcpServer] Server error: $_"
            
        } finally {
            # クリーンアップ
            if ($client) {
                $client.Close()
                $client.Dispose()
            }
            
            if ($listener) {
                $listener.Stop()
            }
            
            $conn = $Global:Connections[$connId]
            if ($conn.Status -ne "ERROR") {
                $conn.Status = "DISCONNECTED"
            }
            $conn.Socket = $null
            
            Write-Host "[TcpServer] Server stopped" -ForegroundColor Yellow
        }
    }
    
    # スレッド開始
    $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
        & $scriptBlock -connId $Connection.Id -localIP $Connection.LocalIP -localPort $Connection.LocalPort
    })
    
    $Connection.Thread = $thread
    $thread.IsBackground = $true
    $thread.Start()
}

# Export-ModuleMember -Function 'Start-TcpServerConnection'
