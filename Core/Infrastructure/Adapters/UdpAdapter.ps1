# Core/Infrastructure/Adapters/UdpAdapter.ps1
# UDP 通信アダプター（新アーキテクチャ準拠）

class UdpAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger

    UdpAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger
    ) {
        if (-not $connectionService) {
            throw "ConnectionService is required for UdpAdapter."
        }
        if (-not $pipeline) {
            throw "ReceivedEventPipeline is required for UdpAdapter."
        }
        if (-not $logger) {
            throw "Logger is required for UdpAdapter."
        }

        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
    }

    <#
    .SYNOPSIS
    UDP 通信を開始する
    
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

        if ($connection.Protocol -ne "UDP") {
            throw "UdpAdapter can only handle UDP connections."
        }

        # ローカルポートの検証
        if ($connection.LocalPort -le 0) {
            throw "Invalid LocalPort for UDP."
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
            param($adapter, $connId, $localIP, $localPort, $remoteIP, $remotePort, $cancellationToken)

            $udpClient = $null
            
            try {
                $adapter._logger.LogInfo("Starting UDP communication", @{
                    ConnectionId = $connId
                    LocalEndpoint = "${localIP}:${localPort}"
                    RemoteEndpoint = if ($remoteIP -and $remotePort -gt 0) { "${remoteIP}:${remotePort}" } else { "Not specified" }
                })

                $conn = $adapter._connectionService.GetConnection($connId)
                if (-not $conn) {
                    throw "Connection not found during thread execution"
                }

                $conn.UpdateStatus("CONNECTING")

                # UDP クライアント作成
                $udpClient = New-Object System.Net.Sockets.UdpClient($localPort)

                # リモートエンドポイント設定（送信用）
                $remoteEndPoint = $null
                if (-not [string]::IsNullOrWhiteSpace($remoteIP) -and $remotePort -gt 0) {
                    $remoteEndPoint = New-Object System.Net.IPEndPoint(
                        [System.Net.IPAddress]::Parse($remoteIP), 
                        $remotePort
                    )
                }

                $conn.UpdateStatus("CONNECTED")
                $conn.State.Socket = $udpClient
                $conn.Socket = $udpClient
                $conn.MarkActivity()

                $adapter._logger.LogInfo("UDP socket ready", @{
                    ConnectionId = $connId
                    LocalEndpoint = "${localIP}:${localPort}"
                })

                # 受信用エンドポイント（任意のアドレスから受信）
                $anyEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)

                # 送受信ループ
                while (-not $cancellationToken.IsCancellationRequested) {
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
                                $targetEndPoint = $null
                                $bytesSent = 0

                                if ($remoteEndPoint) {
                                    # リモートエンドポイント指定済み
                                    $bytesSent = $udpClient.Send($data, $data.Length, $remoteEndPoint)
                                    $targetEndPoint = $remoteEndPoint
                                }
                                elseif ($conn.Variables.ContainsKey('LastRemoteEndPoint')) {
                                    # 最後の受信元に送信
                                    $lastEndPoint = $conn.Variables['LastRemoteEndPoint']
                                    $bytesSent = $udpClient.Send($data, $data.Length, $lastEndPoint)
                                    $targetEndPoint = $lastEndPoint
                                }
                                else {
                                    $adapter._logger.LogWarning("No remote endpoint available for sending", @{
                                        ConnectionId = $connId
                                    })
                                    continue
                                }

                                $adapter._logger.LogInfo("Sent UDP data", @{
                                    ConnectionId = $connId
                                    Length = $bytesSent
                                    Target = $targetEndPoint.ToString()
                                })

                                $conn.MarkActivity()
                            }
                        }

                        # 受信処理（非ブロッキング）
                        if ($udpClient.Available -gt 0) {
                            $receivedData = $udpClient.Receive([ref]$anyEndPoint)

                            if ($receivedData.Length -gt 0) {
                                # 最後の受信元を記録
                                $conn.Variables['LastRemoteEndPoint'] = $anyEndPoint

                                $metadata = @{
                                    RemoteEndPoint = $anyEndPoint.ToString()
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
                            $adapter._logger.LogError("Error in UDP loop", $_.Exception, @{
                                ConnectionId = $connId
                            })
                            break
                        }
                    }
                }

            }
            catch {
                $adapter._logger.LogError("UDP socket error", $_.Exception, @{
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
                if ($udpClient) {
                    try { $udpClient.Close(); $udpClient.Dispose() } catch { }
                }

                $conn = $adapter._connectionService.GetConnection($connId)
                if ($conn) {
                    if ($conn.Status -ne "ERROR") {
                        $conn.UpdateStatus("DISCONNECTED")
                    }
                    $conn.State.Socket = $null
                    $conn.Socket = $null
                }

                $adapter._logger.LogInfo("UDP socket closed", @{
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
                -remoteIP $params.RemoteIP `
                -remotePort $params.RemotePort `
                -cancellationToken $params.CancellationToken
        })

        $connection.State.WorkerThread = $thread
        $connection.Thread = $thread
        $thread.IsBackground = $true
        
        $threadParams = @{
            Adapter = $this
            ConnectionId = $connectionId
            LocalIP = if ($connection.LocalIP) { $connection.LocalIP } else { "0.0.0.0" }
            LocalPort = $connection.LocalPort
            RemoteIP = $connection.RemoteIP
            RemotePort = $connection.RemotePort
            CancellationToken = $connection.CancellationSource.Token
        }
        
        $thread.Start($threadParams)

        $this._logger.LogInfo("UDP thread started", @{
            ConnectionId = $connectionId
            ThreadId = $thread.ManagedThreadId
        })
    }

    <#
    .SYNOPSIS
    UDP 通信を停止する
    
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

        $this._logger.LogInfo("Stopping UDP communication", @{
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
