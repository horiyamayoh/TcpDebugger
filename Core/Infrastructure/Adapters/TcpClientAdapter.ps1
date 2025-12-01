# Core/Infrastructure/Adapters/TcpClientAdapter.ps1
# TCP クライアント接続アダプター（Runspaceアーキテクチャ）

class TcpClientAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger
    hidden [RunspaceMessageQueue]$_messageQueue

    TcpClientAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger,
        [RunspaceMessageQueue]$messageQueue
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
        if (-not $messageQueue) {
            throw "RunspaceMessageQueue is required for TcpClientAdapter."
        }

        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
        $this._messageQueue = $messageQueue
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

        if ([string]::IsNullOrWhiteSpace($connection.RemoteIP) -or $connection.RemotePort -le 0) {
            throw "Invalid RemoteIP or RemotePort for TCP Client."
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
                [string]$RemoteIP,
                [int]$RemotePort,
                [object]$MessageQueue,
                [object]$SendQueueSync,
                [System.Threading.CancellationToken]$CancellationToken
            )
            
            $tcpClient = $null
            $stream = $null
            
            try {
                # ログ: 接続開始
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Connecting to remote server' -Context @{
                    RemoteEndpoint = "${RemoteIP}:${RemotePort}"
                }
                $MessageQueue.Enqueue($msg)
                
                # 状態更新: CONNECTING
                $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'CONNECTING'
                $MessageQueue.Enqueue($msg)
                
                # TCP接続
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $tcpClient.Connect($RemoteIP, $RemotePort)
                
                if (-not $tcpClient.Connected) {
                    throw "Failed to connect to ${RemoteIP}:${RemotePort}"
                }
                
                # 状態更新: CONNECTED
                $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'CONNECTED'
                $MessageQueue.Enqueue($msg)
                
                # アクティビティマーカー
                $msg = New-ActivityMessage -ConnectionId $ConnectionId
                $MessageQueue.Enqueue($msg)
                
                # ログ: 接続成功
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Connected successfully' -Context @{
                    RemoteEndpoint = "${RemoteIP}:${RemotePort}"
                }
                $MessageQueue.Enqueue($msg)
                
                $stream = $tcpClient.GetStream()
                $buffer = New-Object byte[] 8192
                
                # 送受信ループ
                while ($tcpClient.Connected -and -not $CancellationToken.IsCancellationRequested) {
                    # 接続状態を確認（Poll を使用してより確実に検出）
                    $isDisconnected = $false
                    try {
                        if ($tcpClient.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) {
                            if ($tcpClient.Client.Available -eq 0) {
                                # データがなく SelectRead が true = 切断
                                $isDisconnected = $true
                            }
                        }
                    } catch {
                        $isDisconnected = $true
                    }
                    
                    if ($isDisconnected) {
                        # サーバーからの切断を検出
                        $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Server disconnected (detected by Poll)' -Context @{}
                        $MessageQueue.Enqueue($msg)
                        break
                    }
                    
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
                                    
                                    # ログ: 送信
                                    $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Data sent' -Context @{
                                        Length = $data.Length
                                    }
                                    $MessageQueue.Enqueue($msg)
                                    
                                    # アクティビティマーカー
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
                        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
                        
                        if ($bytesRead -gt 0) {
                            # Array.Copy を使用（スライス演算子より高速）
                            $receivedData = [byte[]]::new($bytesRead)
                            [Array]::Copy($buffer, 0, $receivedData, 0, $bytesRead)
                            
                            $metadata = @{
                                RemoteEndPoint = "${RemoteIP}:${RemotePort}"
                            }
                            
                            # データ受信メッセージ（HEX変換はLogger側で実施）
                            $msg = New-DataReceivedMessage -ConnectionId $ConnectionId -Data $receivedData -Metadata $metadata
                            $MessageQueue.Enqueue($msg)
                            
                            # アクティビティマーカー
                            $msg = New-ActivityMessage -ConnectionId $ConnectionId
                            $MessageQueue.Enqueue($msg)
                        } elseif ($bytesRead -eq 0) {
                            # 受信データが0バイト = 切断
                            $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'Server disconnected (0 bytes read)' -Context @{}
                            $MessageQueue.Enqueue($msg)
                            break
                        }
                    }
                    
                    # CPU負荷軽減
                    Start-Sleep -Milliseconds 10
                }
                
            }
            catch {
                # エラーメッセージ
                $msg = New-ErrorMessage -ConnectionId $ConnectionId -Message $_.Exception.Message -Exception $_.Exception
                $MessageQueue.Enqueue($msg)
                
                # ログ: エラー
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Error' -Message 'TCP Client error' -Context @{
                    ErrorMessage = $_.Exception.Message
                }
                $MessageQueue.Enqueue($msg)
            }
            finally {
                # クリーンアップ
                if ($stream) {
                    try { $stream.Close(); $stream.Dispose() } catch { }
                }
                if ($tcpClient) {
                    try { $tcpClient.Close(); $tcpClient.Dispose() } catch { }
                }
                
                # 状態更新: DISCONNECTED
                $msg = New-StatusUpdateMessage -ConnectionId $ConnectionId -Status 'DISCONNECTED'
                $MessageQueue.Enqueue($msg)
                
                # ログ: 切断
                $msg = New-LogMessage -ConnectionId $ConnectionId -Level 'Info' -Message 'TCP Client disconnected' -Context @{}
                $MessageQueue.Enqueue($msg)
            }
        }

        # ScriptBlockを追加してパラメータを設定
        $null = $ps.AddScript($scriptBlock)
        $null = $ps.AddParameter('ConnectionId', $connectionId)
        $null = $ps.AddParameter('RemoteIP', $connection.RemoteIP)
        $null = $ps.AddParameter('RemotePort', $connection.RemotePort)
        $null = $ps.AddParameter('MessageQueue', $this._messageQueue)
        $null = $ps.AddParameter('SendQueueSync', $connection.SendQueue)
        $null = $ps.AddParameter('CancellationToken', $connection.CancellationSource.Token)

        # 非同期実行開始
        $asyncHandle = $ps.BeginInvoke()

        # Runspace関連オブジェクトを保存
        $connection.Variables['_Runspace'] = $runspace
        $connection.Variables['_PowerShell'] = $ps
        $connection.Variables['_AsyncHandle'] = $asyncHandle

        $this._logger.LogInfo("TCP Client Runspace started", @{
            ConnectionId = $connectionId
            RemoteEndpoint = "$($connection.RemoteIP):$($connection.RemotePort)"
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

        $this._logger.LogInfo("Stopping TCP Client", @{
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
        if ($connection.Variables.ContainsKey('_PowerShell')) {
            $ps = $connection.Variables['_PowerShell']
            $asyncHandle = $connection.Variables['_AsyncHandle']
            
            try {
                # Stopを呼び出して中断
                $ps.Stop()
                
                # 終了待機（最大2秒）
                if ($asyncHandle -and -not $asyncHandle.IsCompleted) {
                    $waitHandle = $asyncHandle.AsyncWaitHandle
                    $null = $waitHandle.WaitOne(2000)
                }
                
                # EndInvoke呼び出し（エラーは無視）
                try {
                    $null = $ps.EndInvoke($asyncHandle)
                }
                catch {
                    # Stopした後のEndInvokeはエラーが出ることがあるが無視
                }
                
                # PowerShellとRunspaceを破棄
                $ps.Dispose()
                
                if ($connection.Variables.ContainsKey('_Runspace')) {
                    $runspace = $connection.Variables['_Runspace']
                    $runspace.Close()
                    $runspace.Dispose()
                }
                
                # 変数をクリア
                $connection.Variables.Remove('_PowerShell')
                $connection.Variables.Remove('_Runspace')
                $connection.Variables.Remove('_AsyncHandle')
            }
            catch {
                $this._logger.LogWarning("Error during Runspace cleanup", @{
                    ConnectionId = $connectionId
                    Error = $_.Exception.Message
                })
            }
        }

        $connection.UpdateStatus("DISCONNECTED")
    }
}
