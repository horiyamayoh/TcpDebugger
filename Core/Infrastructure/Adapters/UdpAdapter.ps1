# Core/Infrastructure/Adapters/UdpAdapter.ps1
# UDP 通信アダプター（新アーキテクチャ準拠）

class UdpAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger
    hidden [RunspaceMessageQueue]$_messageQueue

    UdpAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger,
        [RunspaceMessageQueue]$messageQueue
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
        if (-not $messageQueue) {
            throw "RunspaceMessageQueue is required for UdpAdapter."
        }

        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
        $this._messageQueue = $messageQueue
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

        # 既存Runspaceが動作中の場合はキャンセル
        $existingPs = $connection.Variables['_PowerShell']
        if ($existingPs) {
            $this._logger.LogWarning("Runspace already running. Stopping existing Runspace.", @{
                ConnectionId = $connectionId
            })
            $this.Stop($connectionId)
            Start-Sleep -Milliseconds 100
        }

        # 新しいキャンセルトークンソースを作成
        $connection.CancellationSource = [System.Threading.CancellationTokenSource]::new()
        $connection.State.CancellationSource = $connection.CancellationSource

        # Runspaceで非同期実行
        $scriptBlock = {
            param($connId, $localIP, $localPort, $remoteIP, $remotePort, $cancellationToken, $messageQueue)

            # RunspaceMessages.ps1をロード
            $messagesPath = Join-Path $PSScriptRoot "..\..\Domain\RunspaceMessages.ps1"
            $loadScript = ". '$messagesPath'"
            Invoke-Expression $loadScript

            $udpClient = $null
            
            try {
                # 初期ステータス通知
                $messageQueue.Enqueue((New-StatusUpdateMessage -ConnectionId $connId -Status "CONNECTING"))
                $messageQueue.Enqueue((New-LogMessage -ConnectionId $connId -Level "INFO" -Message "Starting UDP communication" -Context @{
                    LocalEndpoint = "${localIP}:${localPort}"
                    RemoteEndpoint = if ($remoteIP -and $remotePort -gt 0) { "${remoteIP}:${remotePort}" } else { "Not specified" }
                }))

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

                # ステータス更新
                $messageQueue.Enqueue((New-StatusUpdateMessage -ConnectionId $connId -Status "CONNECTED"))
                $messageQueue.Enqueue((New-SocketUpdateMessage -ConnectionId $connId -Socket $udpClient))
                $messageQueue.Enqueue((New-ActivityMarkerMessage -ConnectionId $connId))

                $messageQueue.Enqueue((New-LogMessage -ConnectionId $connId -Level "INFO" -Message "UDP socket ready" -Context @{
                    LocalEndpoint = "${localIP}:${localPort}"
                }))

                # 受信用エンドポイント（任意のアドレスから受信）
                $anyEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                $lastRemoteEndPoint = $null

                # 送受信ループ
                while (-not $cancellationToken.IsCancellationRequested) {
                    try {
                        # 送信処理 - SendRequestメッセージをキューから取得
                        # （注: UDPではSendQueueから直接取得できないため、別の仕組みが必要）
                        # 暫定的に従来のSendQueue方式を維持（要改善）

                        # 受信処理（非ブロッキング）
                        if ($udpClient.Available -gt 0) {
                            $receivedData = $udpClient.Receive([ref]$anyEndPoint)

                            if ($receivedData.Length -gt 0) {
                                # 最後の受信元を記録
                                $lastRemoteEndPoint = $anyEndPoint

                                $metadata = @{
                                    RemoteEndPoint = $anyEndPoint.ToString()
                                }

                                # 受信データをメッセージキューに送信（HEX変換はLogger側で実施）
                                $messageQueue.Enqueue((New-DataReceivedMessage -ConnectionId $connId -Data $receivedData -Metadata $metadata))
                                
                                $messageQueue.Enqueue((New-ActivityMarkerMessage -ConnectionId $connId))
                            }
                        }

                        # CPU負荷軽減
                        Start-Sleep -Milliseconds 10

                    }
                    catch {
                        if (-not $cancellationToken.IsCancellationRequested) {
                            $messageQueue.Enqueue((New-ErrorOccurredMessage -ConnectionId $connId -ErrorMessage $_.Exception.Message -Exception $_.Exception))
                            $messageQueue.Enqueue((New-LogMessage -ConnectionId $connId -Level "ERROR" -Message "Error in UDP loop" -Context @{
                                Error = $_.Exception.Message
                            }))
                            break
                        }
                    }
                }

            }
            catch {
                $messageQueue.Enqueue((New-ErrorOccurredMessage -ConnectionId $connId -ErrorMessage $_.Exception.Message -Exception $_.Exception))
                $messageQueue.Enqueue((New-LogMessage -ConnectionId $connId -Level "ERROR" -Message "UDP socket error" -Context @{
                    LocalEndpoint = "${localIP}:${localPort}"
                    Error = $_.Exception.Message
                }))
            }
            finally {
                # クリーンアップ
                if ($udpClient) {
                    try { 
                        $udpClient.Close()
                        $udpClient.Dispose()
                    } catch { }
                }

                $messageQueue.Enqueue((New-StatusUpdateMessage -ConnectionId $connId -Status "DISCONNECTED"))
                $messageQueue.Enqueue((New-SocketUpdateMessage -ConnectionId $connId -Socket $null))
                $messageQueue.Enqueue((New-LogMessage -ConnectionId $connId -Level "INFO" -Message "UDP socket closed"))
            }
        }

        # Runspace作成
        $runspace = [RunspaceFactory]::CreateRunspace()
        $runspace.Open()

        $ps = [PowerShell]::Create()
        $ps.Runspace = $runspace

        # パラメータ設定
        $localIPArg = if ($connection.LocalIP) { $connection.LocalIP } else { "0.0.0.0" }
        
        [void]$ps.AddScript($scriptBlock)
        [void]$ps.AddArgument($connectionId)
        [void]$ps.AddArgument($localIPArg)
        [void]$ps.AddArgument($connection.LocalPort)
        [void]$ps.AddArgument($connection.RemoteIP)
        [void]$ps.AddArgument($connection.RemotePort)
        [void]$ps.AddArgument($connection.CancellationSource.Token)
        [void]$ps.AddArgument($this._messageQueue)

        # 非同期実行開始
        $asyncHandle = $ps.BeginInvoke()

        # Runspace情報を保存
        $connection.Variables['_PowerShell'] = $ps
        $connection.Variables['_AsyncHandle'] = $asyncHandle
        $connection.Variables['_Runspace'] = $runspace

        $this._logger.LogInfo("UDP Runspace started", @{
            ConnectionId = $connectionId
            LocalEndpoint = "${localIPArg}:$($connection.LocalPort)"
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

        $this._logger.LogInfo("Stopping UDP Runspace", @{
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

        $this._logger.LogInfo("UDP Runspace stopped", @{
            ConnectionId = $connectionId
        })
    }
}
