# TcpClient.ps1
# TCP client connection handling

function Start-TcpClientConnection {
    <#
    .SYNOPSIS
    Starts a TCP client connection
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )
    
        param($conn)

        if (-not $conn) {
            return
        }

            $remoteIP = $conn.RemoteIP
            $remotePort = $conn.RemotePort


            # Create TCP client and connect



                # Prepare stream and buffer

                # Send/receive loop
                while ($tcpClient.Connected -and $conn.CancellationSource -and -not $conn.CancellationSource.Token.IsCancellationRequested) {
                        # Flush pending outbound data



                        # Pull inbound data if available




                        # Avoid tight loop

                        if (-not ($conn.CancellationSource -and $conn.CancellationSource.Token.IsCancellationRequested)) {


            if ($conn) {
                $conn.Status = "ERROR"
                $conn.ErrorMessage = $_.Exception.Message
            }

            # Clean up

            if ($conn) {
                if ($conn.Status -ne "ERROR") {
                    $conn.Status = "DISCONNECTED"
                }
                $conn.Socket = $null


    # Launch worker thread
        & $scriptBlock $Connection
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
