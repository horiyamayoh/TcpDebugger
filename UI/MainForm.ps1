# MainForm.ps1
# WinFormsメインフォーム定義

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-MainForm {
    <#
    .SYNOPSIS
    メインフォームを表示
    #>
    
    # メインフォーム作成
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "TCP Test Controller v1.0"
    $form.Size = New-Object System.Drawing.Size(1200, 700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # データグリッドビュー（インスタンス一覧）
    $dgvInstances = New-Object System.Windows.Forms.DataGridView
    $dgvInstances.Location = New-Object System.Drawing.Point(10, 50)
    $dgvInstances.Size = New-Object System.Drawing.Size(1165, 300)
    $dgvInstances.AllowUserToAddRows = $false
    $dgvInstances.AllowUserToDeleteRows = $false
    $dgvInstances.ReadOnly = $false
    $dgvInstances.SelectionMode = "FullRowSelect"
    $dgvInstances.MultiSelect = $false
    $dgvInstances.AutoSizeColumnsMode = "Fill"
    
    # 列定義
    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Name"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $dgvInstances.Columns.Add($colName)
    
    $colProtocol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colProtocol.HeaderText = "Protocol"
    $colProtocol.Name = "Protocol"
    $colProtocol.ReadOnly = $true
    $dgvInstances.Columns.Add($colProtocol)
    
    $colEndpoint = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colEndpoint.HeaderText = "Endpoint"
    $colEndpoint.Name = "Endpoint"
    $colEndpoint.ReadOnly = $true
    $dgvInstances.Columns.Add($colEndpoint)
    
    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Status"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $dgvInstances.Columns.Add($colStatus)
    
    $form.Controls.Add($dgvInstances)
    
    # ツールバー
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Location = New-Object System.Drawing.Point(10, 10)
    $btnRefresh.Size = New-Object System.Drawing.Size(100, 30)
    $btnRefresh.Text = "Refresh"
    $btnRefresh.Add_Click({
        Update-InstanceList -DataGridView $dgvInstances
    })
    $form.Controls.Add($btnRefresh)
    
    $btnConnect = New-Object System.Windows.Forms.Button
    $btnConnect.Location = New-Object System.Drawing.Point(120, 10)
    $btnConnect.Size = New-Object System.Drawing.Size(100, 30)
    $btnConnect.Text = "Connect"
    $btnConnect.Add_Click({
        if ($dgvInstances.SelectedRows.Count -gt 0) {
            $selectedRow = $dgvInstances.SelectedRows[0]
            $connName = $selectedRow.Cells["Name"].Value
            
            # 接続IDを検索
            foreach ($conn in $Global:Connections.Values) {
                if ($conn.Name -eq $connName) {
                    try {
                        Start-Connection -ConnectionId $conn.Id
                        [System.Windows.Forms.MessageBox]::Show("Connection started: $($conn.DisplayName)", "Success")
                        Update-InstanceList -DataGridView $dgvInstances
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Failed to start connection: $_", "Error")
                    }
                    break
                }
            }
        }
    })
    $form.Controls.Add($btnConnect)
    
    $btnDisconnect = New-Object System.Windows.Forms.Button
    $btnDisconnect.Location = New-Object System.Drawing.Point(230, 10)
    $btnDisconnect.Size = New-Object System.Drawing.Size(100, 30)
    $btnDisconnect.Text = "Disconnect"
    $btnDisconnect.Add_Click({
        if ($dgvInstances.SelectedRows.Count -gt 0) {
            $selectedRow = $dgvInstances.SelectedRows[0]
            $connName = $selectedRow.Cells["Name"].Value
            
            foreach ($conn in $Global:Connections.Values) {
                if ($conn.Name -eq $connName) {
                    try {
                        Stop-Connection -ConnectionId $conn.Id
                        [System.Windows.Forms.MessageBox]::Show("Connection stopped: $($conn.DisplayName)", "Success")
                        Update-InstanceList -DataGridView $dgvInstances
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Failed to stop connection: $_", "Error")
                    }
                    break
                }
            }
        }
    })
    $form.Controls.Add($btnDisconnect)
    
    # ログ表示エリア
    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Location = New-Object System.Drawing.Point(10, 360)
    $lblLog.Size = New-Object System.Drawing.Size(200, 20)
    $lblLog.Text = "Connection Log:"
    $form.Controls.Add($lblLog)
    
    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Location = New-Object System.Drawing.Point(10, 385)
    $txtLog.Size = New-Object System.Drawing.Size(1165, 250)
    $txtLog.Multiline = $true
    $txtLog.ScrollBars = "Vertical"
    $txtLog.ReadOnly = $true
    $txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
    $form.Controls.Add($txtLog)
    
    # タイマーで定期更新
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000  # 1秒
    $timer.Add_Tick({
        Update-InstanceList -DataGridView $dgvInstances
        Update-LogDisplay -TextBox $txtLog
    })
    $timer.Start()
    
    # フォームクローズイベント
    $form.Add_FormClosing({
        $timer.Stop()
        
        # 全接続を停止
        foreach ($connId in $Global:Connections.Keys) {
            try {
                Stop-Connection -ConnectionId $connId -Force
            } catch {
                # エラーは無視
            }
        }
    })
    
    # 初期データ表示
    Update-InstanceList -DataGridView $dgvInstances
    
    # フォーム表示
    $form.Add_Shown({$form.Activate()})
    [void]$form.ShowDialog()
}

function Update-InstanceList {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView
    )
    
    # 現在の選択行を保存
    $selectedIndex = if ($DataGridView.SelectedRows.Count -gt 0) { 
        $DataGridView.SelectedRows[0].Index 
    } else { 
        -1 
    }
    
    # データクリア
    $DataGridView.Rows.Clear()
    
    # 接続データを追加
    foreach ($conn in $Global:Connections.Values) {
        $endpoint = ""
        if ($conn.Mode -eq "Client" -or $conn.Mode -eq "Sender") {
            $endpoint = "$($conn.RemoteIP):$($conn.RemotePort)"
        } else {
            $endpoint = "$($conn.LocalIP):$($conn.LocalPort)"
        }
        
        $rowIndex = $DataGridView.Rows.Add(
            $conn.Name,
            "$($conn.Protocol) $($conn.Mode)",
            $endpoint,
            $conn.Status
        )
        
        # 状態に応じて背景色を設定
        $row = $DataGridView.Rows[$rowIndex]
        switch ($conn.Status) {
            "CONNECTED" { 
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen 
            }
            "CONNECTING" { 
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow 
            }
            "ERROR" { 
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral 
            }
            "DISCONNECTED" { 
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGray 
            }
        }
    }
    
    # 選択を復元
    if ($selectedIndex -ge 0 -and $selectedIndex -lt $DataGridView.Rows.Count) {
        $DataGridView.Rows[$selectedIndex].Selected = $true
    }
}

function Update-LogDisplay {
    param(
        [System.Windows.Forms.TextBox]$TextBox
    )
    
    # 最新100件のログを表示
    $logLines = @()
    
    foreach ($conn in $Global:Connections.Values) {
        # 送信ログ
        foreach ($item in $conn.SendQueue) {
            # キューは送信待ちなので表示しない
        }
        
        # 受信ログ（最新10件）
        $recentRecv = $conn.RecvBuffer | Select-Object -Last 10
        foreach ($recv in $recentRecv) {
            $summary = Get-MessageSummary -Data $recv.Data -MaxLength 40
            $timeStr = $recv.Timestamp.ToString("HH:mm:ss")
            $logLines += "[$timeStr] $($conn.Name) ? $summary ($($recv.Length) bytes)"
        }
    }
    
    # 最新100行に制限
    $logLines = $logLines | Select-Object -Last 100
    
    # テキストボックスに表示
    $TextBox.Text = $logLines -join "`r`n"
    
    # 最下部にスクロール
    $TextBox.SelectionStart = $TextBox.Text.Length
    $TextBox.ScrollToCaret()
}

# Export-ModuleMember -Function 'Show-MainForm'
