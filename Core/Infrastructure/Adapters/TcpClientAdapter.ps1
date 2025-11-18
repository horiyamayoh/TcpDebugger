# Core/Infrastructure/Adapters/TcpClientAdapter.ps1
# TCP クライアント接続アダプター（新アーキテクチャ準拠）

class TcpClientAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger

    TcpClientAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger
    ) {
        if (-not $connectionService) {
            throw "ConnectionService is required for TcpClientAdapter."
        }
        if (-not $pipeline) {
            throw "ReceivedEventPipeline is required for TcpClientAdapter."
        }
        if (-not $logger) {
            throw "Logger is required for TcpClientAdapter."
        }

        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
    }

    <#
    .SYNOPSIS
    TCP クライアント接続を開始する
    
    .PARAMETER connectionId
    接続ID（ManagedConnection.Id）
    #>
    [void] Start([string]$connectionId) {
        if ([string]::IsNullOrWhiteSpace($connectionId)) {
            throw "Connection ID cannot be null or empty."
        }

        $connection = $this._connectionService.GetConnection($connectionId)
        if (-not $connection) {
            throw "Connection not found: $connectionId"
        }

        if ($connection.Protocol -ne "TCP") {
            throw "TcpClientAdapter can only handle TCP connections."
        }

        if ($connection.Mode -ne "Client") {
            throw "TcpClientAdapter requires Mode='Client'."
        }

        # リモートIPとポートの検証
        if ([string]::IsNullOrWhiteSpace($connection.RemoteIP) -or $connection.RemotePort -le 0) {
            throw "Invalid RemoteIP or RemotePort for TCP Client."
        }

        # 既存スレッドが動作中の場合はキャンセル
        if ($connection.State.WorkerThread -and $connection.State.WorkerThread.IsAlive) {
            $this._logger.LogWarning("Worker thread already running. Cancelling existing thread.", @{
                ConnectionId = $connectionId
            })
            $connection.CancellationSource.Cancel()
            Start-Sleep -Milliseconds 100
        }

        # 新しいキャンセルトークンソースを作成
        $connection.CancellationSource = [System.Threading.CancellationTokenSource]::new()
        $connection.State.CancellationSource = $connection.CancellationSource

        # スレッドで非同期実行
        $scriptBlock = {
            param($adapter, $connId, $remoteIP, $remotePort, $cancellationToken)

            $tcpClient = $null
            $stream = $null
            
            try {
                $adapter._logger.LogInfo("Connecting to remote server", @{
                    ConnectionId = $connId
                    RemoteEndpoint = "${remoteIP}:${remotePort}"
                })

                $conn = $adapter._connectionService.GetConnection($connId)
                if (-not $conn) {
                    throw "Connection not found during thread execution"
                }

                $conn.UpdateStatus("CONNECTING")

                # TCP クライアント作成と接続
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $tcpClient.Connect($remoteIP, $remotePort)

                if (-not $tcpClient.Connected) {
                    throw "Failed to connect to ${remoteIP}:${remotePort}"
                }

                # 接続成功
                $conn.UpdateStatus("CONNECTED")
                $conn.SetSocket($tcpClient)
                $conn.MarkActivity()

                $adapter._logger.LogInfo("TCP Client connected successfully", @{
                    ConnectionId = $connId
                    RemoteEndpoint = "${remoteIP}:${remotePort}"
                })

                # ストリーム取得
                $stream = $tcpClient.GetStream()
                $buffer = New-Object byte[] 8192

                # 送受信ループ
                while ($tcpClient.Connected -and -not $cancellationToken.IsCancellationRequested) {
                    try {
                        # 送信処理
                        while ($conn.SendQueue.Count -gt 0) {
                            $data = $null
                            $syncRoot = [System.Collections.ArrayList]::Synchronized($conn.SendQueue).SyncRoot
                            [System.Threading.Monitor]::Enter($syncRoot)
                            try {
                                if ($conn.SendQueue.Count -gt 0) {
                                    $data = $conn.SendQueue[0]
                                    $conn.SendQueue.RemoveAt(0)
                                }
                            }
                            finally {
                                [System.Threading.Monitor]::Exit($syncRoot)
                            }

                            if ($data) {
                                $stream.Write($data, 0, $data.Length)
                                $stream.Flush()

                                $adapter._logger.LogInfo("Sent data to server", @{
                                    ConnectionId = $connId
                                    Length = $data.Length
                                })

                                $conn.MarkActivity()
                            }
                        }

                        # 受信処理（非ブロッキング）
                        if ($stream.DataAvailable) {
                            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

                            if ($bytesRead -gt 0) {
                                $receivedData = $buffer[0..($bytesRead - 1)]

                                $metadata = @{
                                    RemoteEndPoint = "${remoteIP}:${remotePort}"
                                }

                                # ReceivedEventPipeline経由で受信イベントを処理
                                $adapter._pipeline.ProcessEvent($connId, $receivedData, $metadata)
                            }
                        }

                        # CPU負荷軽減
                        Start-Sleep -Milliseconds 10

                    }
                    catch {
                        if (-not $cancellationToken.IsCancellationRequested) {
                            $adapter._logger.LogError("Error in TCP client loop", $_.Exception, @{
                                ConnectionId = $connId
                            })
                            break
                        }
                    }
                }

            }
            catch {
                $adapter._logger.LogError("TCP Client connection error", $_.Exception, @{
                    ConnectionId = $connId
                    RemoteEndpoint = "${remoteIP}:${remotePort}"
                })

                $conn = $adapter._connectionService.GetConnection($connId)
                if ($conn) {
                    $conn.SetError($_.Exception.Message, $_.Exception)
                }
            }
            finally {
                # クリーンアップ
                if ($stream) {
                    try { $stream.Close(); $stream.Dispose() } catch { }
                }
                if ($tcpClient) {
                    try { $tcpClient.Close(); $tcpClient.Dispose() } catch { }
                }

                $conn = $adapter._connectionService.GetConnection($connId)
                if ($conn) {
                    if ($conn.Status -ne "ERROR") {
                        $conn.UpdateStatus("DISCONNECTED")
                    }
                    $conn.ClearSocket()
                }

                $adapter._logger.LogInfo("TCP Client connection closed", @{
                    ConnectionId = $connId
                })
            }
        }

        # スレッド開始
        $thread = New-Object System.Threading.Thread([System.Threading.ParameterizedThreadStart]{
            param($params)
            try {
                & $params.ScriptBlock `
                    -adapter $params.Adapter `
                    -connId $params.ConnectionId `
                    -remoteIP $params.RemoteIP `
                    -remotePort $params.RemotePort `
                    -cancellationToken $params.CancellationToken
            }
            catch {
                # ?X???b?h???O??G???[???L???b?`????N???b?V????h?
                try {
                    $params.Adapter._logger.LogError("Fatal error in worker thread", $_.Exception, @{
                        ConnectionId = $params.ConnectionId
                        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    })
                }
                catch {
                    # ???O???o?????s?s??????A???C???R???[????o??
                    Write-Host "[FATAL THREAD ERROR] $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        })

        $connection.State.WorkerThread = $thread
        $connection.Thread = $thread
        $thread.IsBackground = $true
        
        $threadParams = @{
            Adapter = $this
            ConnectionId = $connectionId
            RemoteIP = $connection.RemoteIP
            RemotePort = $connection.RemotePort
            CancellationToken = $connection.CancellationSource.Token
            ScriptBlock = $scriptBlock  # scriptBlock???Q??????
        }
        
        $thread.Start($threadParams)

        $this._logger.LogInfo("TCP Client thread started", @{
            ConnectionId = $connectionId
            ThreadId = $thread.ManagedThreadId
        })
    }

    <#
    .SYNOPSIS
    TCP クライアント接続を停止する
    
    .PARAMETER connectionId
    接続ID
    #>
    [void] Stop([string]$connectionId) {
        if ([string]::IsNullOrWhiteSpace($connectionId)) {
            return
        }

        $connection = $this._connectionService.GetConnection($connectionId)
        if (-not $connection) {
            return
        }

        $this._logger.LogInfo("Stopping TCP Client connection", @{
            ConnectionId = $connectionId
        })

        # キャンセルトークンを発行
        if ($connection.CancellationSource) {
            try {
                $connection.CancellationSource.Cancel()
            }
            catch {
                $this._logger.LogWarning("Failed to cancel connection", @{
                    ConnectionId = $connectionId
                    Error = $_.Exception.Message
                })
            }
        }

        # スレッドの終了を待機（最大2秒）
        if ($connection.State.WorkerThread -and $connection.State.WorkerThread.IsAlive) {
            $waitResult = $connection.State.WorkerThread.Join(2000)
            if (-not $waitResult) {
                $this._logger.LogWarning("Thread did not stop gracefully within timeout", @{
                    ConnectionId = $connectionId
                })
            }
        }

        $connection.UpdateStatus("DISCONNECTED")
    }
}
