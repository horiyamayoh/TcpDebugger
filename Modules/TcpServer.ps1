# TcpServer.ps1
# TCP server connection handling

function Start-TcpServerConnection {
    <#
    .SYNOPSIS
    Starts a TCP server listener
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )
    
    # Run work on background thread
    $scriptBlock = {
        param($conn)

        if (-not $conn) {
            return
        }

        try {
            $localIP = $conn.LocalIP
            $localPort = $conn.LocalPort

            Write-Host "[TcpServer] Starting server on ${localIP}:${localPort}..." -ForegroundColor Cyan

            # Start TCP listener
            $ipAddress = [System.Net.IPAddress]::Parse($localIP)
            $listener = New-Object System.Net.Sockets.TcpListener($ipAddress, $localPort)
            $listener.Start()

            $conn.Socket = $listener
            $conn.Status = "CONNECTED"

            Write-Host "[TcpServer] Server listening on ${localIP}:${localPort}" -ForegroundColor Green

            # Track current client and stream
            $client = $null
            $stream = $null

            while ($conn.CancellationSource -and -not $conn.CancellationSource.Token.IsCancellationRequested) {
                try {
                    # Accept a client if one is waiting
                    if ($listener.Pending()) {
                        if ($client) {
                            $client.Close()
                        }

                        $client = $listener.AcceptTcpClient()
                        $stream = $client.GetStream()

                        $remoteEndpoint = $client.Client.RemoteEndPoint
                        Write-Host "[TcpServer] Client connected: $remoteEndpoint" -ForegroundColor Green
                    }

                    # Handle active client traffic
                    if ($client -and $client.Connected) {
                        # Flush outbound queue
                        while ($conn.SendQueue.Count -gt 0) {
                            $data = $conn.SendQueue[0]
                            $conn.SendQueue.RemoveAt(0)

                            $stream.Write($data, 0, $data.Length)
                            $stream.Flush()

                            Write-Host "[TcpServer] Sent $($data.Length) bytes" -ForegroundColor Blue
                            $conn.LastActivity = Get-Date
                        }

                        # Receive inbound data
                        if ($stream.DataAvailable) {
                            $buffer = New-Object byte[] 8192
                            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

                            if ($bytesRead -gt 0) {
                                $receivedData = $buffer[0..($bytesRead-1)]

                                [void]$conn.RecvBuffer.Add([PSCustomObject]@{
                                    Timestamp = Get-Date
                                    Data = $receivedData
                                    Length = $bytesRead
                                })

                                Write-Host "[TcpServer] Received $bytesRead bytes" -ForegroundColor Magenta
                                $conn.LastActivity = Get-Date
                            }
                        }
                    }

                    # Avoid busy wait
                    Start-Sleep -Milliseconds 10

                } catch {
                    if (-not ($conn.CancellationSource -and $conn.CancellationSource.Token.IsCancellationRequested)) {
                        Write-Error "[TcpServer] Error in loop: $_"
                    }
                }
            }

        } catch {
            if ($conn) {
                $conn.Status = "ERROR"
                $conn.ErrorMessage = $_.Exception.Message
            }
            Write-Error "[TcpServer] Server error: $_"

        } finally {
            # Clean up listener and client
            if ($client) {
                $client.Close()
                $client.Dispose()
            }

            if ($listener) {
                $listener.Stop()
            }

            if ($conn) {
                if ($conn.Status -ne "ERROR") {
                    $conn.Status = "DISCONNECTED"
                }
                $conn.Socket = $null
            }

            Write-Host "[TcpServer] Server stopped" -ForegroundColor Yellow
        }
    }

    # Launch worker thread
    $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
        & $scriptBlock $Connection
    })
    $Connection.Thread = $thread
    $thread.IsBackground = $true
    $thread.Start()
}

# Export-ModuleMember -Function 'Start-TcpServerConnection'
