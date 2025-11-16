# Core/Infrastructure/Adapters/TcpServerAdapter.ps1
# TCP サーバー接続アダプター（新アーキテクチャ準拠）

class TcpServerAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger

    TcpServerAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger
    ) {
        if (-not $connectionService) {
            throw "ConnectionService is required for TcpServerAdapter."
        }
        if (-not $pipeline) {
            throw "ReceivedEventPipeline is required for TcpServerAdapter."
        }
        if (-not $logger) {
            throw "Logger is required for TcpServerAdapter."
        }

        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
    }

    <#
    .SYNOPSIS
    TCP サーバーを起動する
    
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
            throw "TcpServerAdapter can only handle TCP connections."
        }

        if ($connection.Mode -ne "Server") {
            throw "TcpServerAdapter requires Mode='Server'."
        }

        # ローカルIPとポートの検証
        if ([string]::IsNullOrWhiteSpace($connection.LocalIP) -or $connection.LocalPort -le 0) {
            throw "Invalid LocalIP or LocalPort for TCP Server."
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
            param($adapter, $connId, $localIP, $localPort, $cancellationToken)

            $listener = $null
            $client = $null
            $stream = $null
            
            try {
                $adapter._logger.LogInfo("Starting TCP Server", @{
                    ConnectionId = $connId
                    LocalEndpoint = "${localIP}:${localPort}"
                })

                $conn = $adapter._connectionService.GetConnection($connId)
                if (-not $conn) {
                    throw "Connection not found during thread execution"
                }

                $conn.UpdateStatus("CONNECTING")

                # TCP リスナー作成
                $ipAddress = [System.Net.IPAddress]::Parse($localIP)
                $listener = New-Object System.Net.Sockets.TcpListener($ipAddress, $localPort)
                $listener.Start()

                $conn.UpdateStatus("CONNECTED")
                $conn.State.Socket = $listener
                $conn.Socket = $listener
                $conn.MarkActivity()

                $adapter._logger.LogInfo("TCP Server listening successfully", @{
                    ConnectionId = $connId
                    LocalEndpoint = "${localIP}:${localPort}"
                })

                # クライアント接続待機ループ
                while (-not $cancellationToken.IsCancellationRequested) {
                    try {
                        # 接続待機（ポーリング方式）
                        if ($listener.Pending()) {
                            # 既存クライアントがあればクローズ（シングル接続モード）
                            if ($client) {
                                try {
                                    if ($stream) { $stream.Close(); $stream.Dispose(); $stream = $null }
                                    $client.Close(); $client.Dispose()
                                }
                                catch { }
                            }

                            $client = $listener.AcceptTcpClient()
                            $stream = $client.GetStream()

                            $remoteEndpoint = $client.Client.RemoteEndPoint.ToString()
                            
                            $adapter._logger.LogInfo("TCP Server accepted client connection", @{
                                ConnectionId = $connId
                                RemoteEndpoint = $remoteEndpoint
                            })
                        }

                        # クライアントが接続中の場合、送受信処理
                        if ($client -and $client.Connected) {
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

                                    $adapter._logger.LogInfo("Sent data to client", @{
                                        ConnectionId = $connId
                                        Length = $data.Length
                                    })

                                    $conn.MarkActivity()
                                }
                            }

                            # 受信処理（非ブロッキング）
                            if ($stream.DataAvailable) {
                                $buffer = New-Object byte[] 8192
                                $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

                                if ($bytesRead -gt 0) {
                                    $receivedData = $buffer[0..($bytesRead - 1)]

                                    $metadata = @{
                                        RemoteEndPoint = $client.Client.RemoteEndPoint.ToString()
                                    }

                                    # ReceivedEventPipeline経由で受信イベントを処理
                                    $adapter._pipeline.ProcessEvent($connId, $receivedData, $metadata)
                                }
                            }
                        }

                        # CPU負荷軽減
                        Start-Sleep -Milliseconds 10

                    }
                    catch {
                        if (-not $cancellationToken.IsCancellationRequested) {
                            $adapter._logger.LogError("Error in TCP server loop", $_.Exception, @{
                                ConnectionId = $connId
                            })
                        }
                    }
                }

            }
            catch {
                $adapter._logger.LogError("TCP Server error", $_.Exception, @{
                    ConnectionId = $connId
                    LocalEndpoint = "${localIP}:${localPort}"
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
                if ($client) {
                    try { $client.Close(); $client.Dispose() } catch { }
                }
                if ($listener) {
                    try { $listener.Stop() } catch { }
                }

                $conn = $adapter._connectionService.GetConnection($connId)
                if ($conn) {
                    if ($conn.Status -ne "ERROR") {
                        $conn.UpdateStatus("DISCONNECTED")
                    }
                    $conn.State.Socket = $null
                    $conn.Socket = $null
                }

                $adapter._logger.LogInfo("TCP Server stopped", @{
                    ConnectionId = $connId
                })
            }
        }

        # スレッド開始
        $thread = New-Object System.Threading.Thread([System.Threading.ParameterizedThreadStart]{
            param($params)
            & $scriptBlock `
                -adapter $params.Adapter `
                -connId $params.ConnectionId `
                -localIP $params.LocalIP `
                -localPort $params.LocalPort `
                -cancellationToken $params.CancellationToken
        })

        $connection.State.WorkerThread = $thread
        $connection.Thread = $thread
        $thread.IsBackground = $true
        
        $threadParams = @{
            Adapter = $this
            ConnectionId = $connectionId
            LocalIP = $connection.LocalIP
            LocalPort = $connection.LocalPort
            CancellationToken = $connection.CancellationSource.Token
        }
        
        $thread.Start($threadParams)

        $this._logger.LogInfo("TCP Server thread started", @{
            ConnectionId = $connectionId
            ThreadId = $thread.ManagedThreadId
        })
    }

    <#
    .SYNOPSIS
    TCP サーバーを停止する
    
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

        $this._logger.LogInfo("Stopping TCP Server", @{
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
