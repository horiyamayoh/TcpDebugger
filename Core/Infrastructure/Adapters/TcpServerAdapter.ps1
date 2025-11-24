# Core/Infrastructure/Adapters/TcpServerAdapter.ps1
# TCP サーバー接続アダプター（新アーキテクチャ準拠）

class TcpServerAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger
    hidden [RunspaceMessageQueue]$_messageQueue

    TcpServerAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger,
        [RunspaceMessageQueue]$messageQueue
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
        if (-not $messageQueue) {
            throw "RunspaceMessageQueue is required for TcpServerAdapter."
        }

        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
        $this._messageQueue = $messageQueue
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

        if ([string]::IsNullOrWhiteSpace($connection.LocalIP) -or $connection.LocalPort -le 0) {
            throw "Invalid LocalIP or LocalPort for TCP Server."
        }

        # 既存Runspaceが動作中の場合は停止
        if ($connection.Variables.ContainsKey('_PowerShell')) {
            $this._logger.LogWarning("PowerShell Runspace already running. Stopping existing runspace.", @{
                ConnectionId = $connectionId
            })
            $this.Stop($connectionId)
            Start-Sleep -Milliseconds 100
        }

        # 新しいキャンセルトークンソースを作成
        $connection.CancellationSource = [System.Threading.CancellationTokenSource]::new()

        # Runspace作成
        $runspace = [RunspaceFactory]::CreateRunspace()
        $runspace.Open()

        # PowerShellインスタンス作成
        $ps = [PowerShell]::Create()
        $ps.Runspace = $runspace

        # RunspaceMessages.ps1のパスを取得してドットソース
        $messagesPath = Join-Path $PSScriptRoot "..\..\Domain\RunspaceMessages.ps1"
        $loadScript = ". '$messagesPath'"
        $null = $ps.AddScript($loadScript).Invoke()
        $ps.Commands.Clear()

        # メインScriptBlock
        $scriptBlock = {
            param(
                [string]$ConnectionId,
                [string]$LocalIP,
                [int]$LocalPort,
                [object]$MessageQueue,
                [object]$SendQueueSync,
                [System.Threading.CancellationToken]$CancellationToken
            )
            
            $listener = $null
            $client = $null
            $stream = $null
            
            try {
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Starting TCP Server' -Context @{
                    LocalEndpoint = "${LocalIP}:${LocalPort}"
                }
                $MessageQueue.Enqueue($msg)
                
                $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'CONNECTING'
                $MessageQueue.Enqueue($msg)
                
                # TCP リスナー作成
                $ipAddress = [System.Net.IPAddress]::Parse($LocalIP)
                $listener = New-Object System.Net.Sockets.TcpListener($ipAddress, $LocalPort)
                $listener.Start()
                
                # TCP サーバーは Listen 状態であり、まだクライアント接続はない
                $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'LISTENING'
                $MessageQueue.Enqueue($msg)
                
                $msg = New-ActivityMessage -ConnectionId $ConnectionId
                $MessageQueue.Enqueue($msg)
                
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'TCP Server listening for connections' -Context @{
                    LocalEndpoint = "${LocalIP}:${LocalPort}"
                }
                $MessageQueue.Enqueue($msg)
                
                # クライアント接続待機ループ
                while (-not $CancellationToken.IsCancellationRequested) {
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
                            
                            # クライアント接続完了 → Status を CONNECTED に更新
                            $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'CONNECTED'
                            $MessageQueue.Enqueue($msg)
                            
                            $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'TCP Server accepted client connection' -Context @{
                                RemoteEndpoint = $remoteEndpoint
                            }
                            $MessageQueue.Enqueue($msg)
                        }

                        # クライアントが接続中の場合、送受信処理
                        if ($client -and $client.Connected) {
                            # 送信処理
                            if ($SendQueueSync -and $SendQueueSync.Count -gt 0) {
                                [System.Threading.Monitor]::Enter($SendQueueSync.SyncRoot)
                                try {
                                    while ($SendQueueSync.Count -gt 0) {
                                        $data = $SendQueueSync[0]
                                        $SendQueueSync.RemoveAt(0)
                                        
                                        if ($data) {
                                            $stream.Write($data, 0, $data.Length)
                                            $stream.Flush()
                                            
                                            $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Sent data to client' -Context @{
                                                Length = $data.Length
                                            }
                                            $MessageQueue.Enqueue($msg)
                                            
                                            $msg = New-ActivityMessage -ConnectionId $ConnectionId
                                            $MessageQueue.Enqueue($msg)
                                        }
                                    }
                                }
                                finally {
                                    [System.Threading.Monitor]::Exit($SendQueueSync.SyncRoot)
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

                                    $msg = New-DataReceivedMessage -ConnectionId $ConnectionId -Data $receivedData -Metadata $metadata
                                    $MessageQueue.Enqueue($msg)
                                    
                                    $msg = New-ActivityMessage -ConnectionId $ConnectionId
                                    $MessageQueue.Enqueue($msg)
                                } else {
                                    # クライアント切断を検出
                                    $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Client disconnected' -Context @{}
                                    $MessageQueue.Enqueue($msg)
                                    
                                    if ($stream) { $stream.Close(); $stream.Dispose(); $stream = $null }
                                    if ($client) { $client.Close(); $client.Dispose(); $client = $null }
                                    
                                    # Status を LISTENING に戻す
                                    $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'LISTENING'
                                    $MessageQueue.Enqueue($msg)
                                }
                            }
                        } elseif ($client -and -not $client.Connected) {
                            # クライアントが切断された場合
                            $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Client connection lost' -Context @{}
                            $MessageQueue.Enqueue($msg)
                            
                            if ($stream) { $stream.Close(); $stream.Dispose(); $stream = $null }
                            if ($client) { $client.Close(); $client.Dispose(); $client = $null }
                            
                            # Status を LISTENING に戻す
                            $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'LISTENING'
                            $MessageQueue.Enqueue($msg)
                        }

                        # CPU負荷軽減
                        Start-Sleep -Milliseconds 10

                    }
                    catch {
                        if (-not $CancellationToken.IsCancellationRequested) {
                            $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Error' -Message 'Error in TCP server loop' -Context @{
                                ErrorMessage = $_.Exception.Message
                            }
                            $MessageQueue.Enqueue($msg)
                        }
                    }
                }

            }
            catch {
                $msg = New-ErrorMessage -ConnectionId $ConnectionId -Message $_.Exception.Message -Exception $_.Exception
                $MessageQueue.Enqueue($msg)
                
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Error' -Message 'TCP Server error' -Context @{
                    ErrorMessage = $_.Exception.Message
                }
                $MessageQueue.Enqueue($msg)
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

                $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'DISCONNECTED'
                $MessageQueue.Enqueue($msg)
                
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'TCP Server stopped' -Context @{}
                $MessageQueue.Enqueue($msg)
            }
        }

        # ScriptBlockを追加してパラメータを設定
        $null = $ps.AddScript($scriptBlock)
        $null = $ps.AddParameter('ConnectionId', $connectionId)
        $null = $ps.AddParameter('LocalIP', $connection.LocalIP)
        $null = $ps.AddParameter('LocalPort', $connection.LocalPort)
        $null = $ps.AddParameter('MessageQueue', $this._messageQueue)
        $null = $ps.AddParameter('SendQueueSync', $connection.SendQueue)
        $null = $ps.AddParameter('CancellationToken', $connection.CancellationSource.Token)

        # 非同期実行開始
        $asyncHandle = $ps.BeginInvoke()

        # Runspace関連オブジェクトを保存
        $connection.Variables['_Runspace'] = $runspace
        $connection.Variables['_PowerShell'] = $ps
        $connection.Variables['_AsyncHandle'] = $asyncHandle

        $this._logger.LogInfo("TCP Server Runspace started", @{
            ConnectionId = $connectionId
            LocalEndpoint = "$($connection.LocalIP):$($connection.LocalPort)"
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

        $this._logger.LogInfo("Stopping TCP Server Runspace", @{
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

        # Runspaceの停止
        $ps = $connection.Variables['_PowerShell']
        $asyncHandle = $connection.Variables['_AsyncHandle']
        $runspace = $connection.Variables['_Runspace']

        if ($ps) {
            try {
                # 実行中のRunspaceを停止
                if ($ps.InvocationStateInfo.State -eq [System.Management.Automation.PSInvocationState]::Running) {
                    $this._logger.LogInfo("Stopping Runspace execution", @{
                        ConnectionId = $connectionId
                    })
                    $ps.Stop()
                }

                # 非同期実行の完了を待機（最大2秒）
                if ($asyncHandle) {
                    try {
                        $ps.EndInvoke($asyncHandle)
                    }
                    catch {
                        # EndInvokeでエラーが発生してもログだけ記録
                        $this._logger.LogWarning("Error during EndInvoke", @{
                            ConnectionId = $connectionId
                            Error = $_.Exception.Message
                        })
                    }
                }
            }
            catch {
                $this._logger.LogWarning("Error stopping Runspace", @{
                    ConnectionId = $connectionId
                    Error = $_.Exception.Message
                })
            }
            finally {
                # PowerShellオブジェクトの破棄
                try {
                    $ps.Dispose()
                }
                catch {
                    $this._logger.LogWarning("Error disposing PowerShell object", @{
                        ConnectionId = $connectionId
                        Error = $_.Exception.Message
                    })
                }
            }
        }

        # Runspaceの破棄
        if ($runspace) {
            try {
                if ($runspace.RunspaceStateInfo.State -ne [System.Management.Automation.Runspaces.RunspaceState]::Closed) {
                    $runspace.Close()
                }
                $runspace.Dispose()
            }
            catch {
                $this._logger.LogWarning("Error disposing Runspace", @{
                    ConnectionId = $connectionId
                    Error = $_.Exception.Message
                })
            }
        }

        # 変数のクリーンアップ
        $connection.Variables.Remove('_PowerShell')
        $connection.Variables.Remove('_AsyncHandle')
        $connection.Variables.Remove('_Runspace')

        $connection.UpdateStatus("DISCONNECTED")

        $this._logger.LogInfo("TCP Server Runspace stopped", @{
            ConnectionId = $connectionId
        })
    }
}
