# ViewBuilder.ps1
# Responsible for creating WinForms UI controls

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-MainFormWindow {
    <#
    .SYNOPSIS
    Creates the main form window.
    
    .PARAMETER Title
    The title of the window.
    
    .PARAMETER Width
    The width of the window.
    
    .PARAMETER Height
    The height of the window.
    #>
    param(
        [string]$Title = "Socket Debugger Simple v1.0",
        [int]$Width = 1400,
        [int]$Height = 800
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.MinimumSize = New-Object System.Drawing.Size(1200, 600)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    
    # アイコン設定
    # カスタムアイコンファイルがあれば使用、なければPowerShellアイコンを使用
    $customIconPath = Join-Path $PSScriptRoot "..\..\Resources\tcp-debugger.ico"
    if (Test-Path -LiteralPath $customIconPath -ErrorAction SilentlyContinue) {
        try {
            $form.Icon = New-Object System.Drawing.Icon($customIconPath)
        }
        catch {
            # カスタムアイコンの読み込みに失敗した場合はPowerShellアイコンを使用
            $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
        }
    }
    else {
        # カスタムアイコンがない場合はPowerShellアイコンを使用
        $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
    }

    return $form
}

function New-ConnectionDataGridView {
    <#
    .SYNOPSIS
    Creates the DataGridView for displaying connections.
    #>
    param(
        [int]$X = 10,
        [int]$Y = 50,
        [int]$Width = 1160,
        [int]$Height = 230
    )
    
    $dgv = New-Object System.Windows.Forms.DataGridView
    $dgv.Location = New-Object System.Drawing.Point($X, $Y)
    $dgv.Size = New-Object System.Drawing.Size($Width, $Height)
    
    # ダブルバッファリングを有効化（ちらつき防止）
    $dgvType = $dgv.GetType()
    $propInfo = $dgvType.GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    if ($propInfo) {
        $propInfo.SetValue($dgv, $true, $null)
    }
    
    $dgv.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor 
                  [System.Windows.Forms.AnchorStyles]::Bottom -bor 
                  [System.Windows.Forms.AnchorStyles]::Left -bor 
                  [System.Windows.Forms.AnchorStyles]::Right
    $dgv.AllowUserToAddRows = $false
    $dgv.AllowUserToDeleteRows = $false
    $dgv.AllowUserToResizeRows = $false
    $dgv.RowHeadersVisible = $false
    $dgv.ReadOnly = $false
    $dgv.SelectionMode = "CellSelect"
    $dgv.MultiSelect = $false
    $dgv.AutoSizeColumnsMode = "Fill"
    $dgv.AutoGenerateColumns = $false
    $dgv.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter
    $dgv.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
    $dgv.BackgroundColor = [System.Drawing.Color]::White
    $dgv.GridColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $dgv.EnableHeadersVisualStyles = $false
    
    # グループヘッダー構成
    [int]$groupHeaderHeight = 24
    [int]$subHeaderHeight = 24
    [int]$groupHeaderPaddingTop = [Math]::Max($groupHeaderHeight - 3, 0)
    
    # 1行目に表示する単独列（グループなし）
    $singleColumns = @('Name', 'Protocol', 'Status', 'BtnConnect', 'BtnDisconnect', 'Profile')
    
    # グループ化された列
    $headerGroups = @(
        [PSCustomObject]@{
            Title   = 'Endpoint'
            Columns = @('LocalEndpoint', 'RemoteEndpoint')
            Color   = [System.Drawing.Color]::FromArgb(45, 45, 48)
        }
        [PSCustomObject]@{
            Title   = 'On Receive'
            Columns = @('Scenario', 'OnReceiveScript')
            Color   = [System.Drawing.Color]::FromArgb(45, 45, 48)
        }
        [PSCustomObject]@{
            Title   = 'On Timer'
            Columns = @('OnTimerSend')
            Color   = [System.Drawing.Color]::FromArgb(45, 45, 48)
        }
        [PSCustomObject]@{
            Title   = 'Manual'
            Columns = @('ManualSend', 'QuickSend', 'ManualScript', 'ActionSend')
            Color   = [System.Drawing.Color]::FromArgb(45, 45, 48)
        }
    )
    $dgv.Tag = @{ 
        HeaderGroups = $headerGroups
        SingleColumns = $singleColumns
        GroupHeaderHeight = $groupHeaderHeight 
    }

    # ヘッダーのスタイル設定（2行構成）
    $dgv.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $dgv.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $dgv.ColumnHeadersDefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::BottomCenter
    $dgv.ColumnHeadersDefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(0, $groupHeaderPaddingTop, 0, 3)
    $dgv.ColumnHeadersDefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::False
    $dgv.ColumnHeadersHeight = $groupHeaderHeight + $subHeaderHeight
    $dgv.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing

    # Disable visual selection
    $dgv.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
    $dgv.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $dgv.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::White
    $dgv.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $dgv.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(3, 2, 3, 2)

    # 行の高さを少し増やして見やすく
    $dgv.RowTemplate.Height = 28

    # グループヘッダーをPaintイベントで描画（オーバーレイ）
    $dgv.Add_Paint({
        param($sender, $e)
        
        try {
            if (-not $sender.Tag) { return }
            
            $graphics = $e.Graphics
            $groupHeight = $sender.Tag.GroupHeaderHeight
            $headerGroups = $sender.Tag.HeaderGroups
            $singleColumns = $sender.Tag.SingleColumns
            $titleFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $backBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 45, 48))
            $gridPen = New-Object System.Drawing.Pen($sender.GridColor, 1)
            
            # テキスト描画用フォーマット（折り返しなし、省略記号表示）
            $textFormat = New-Object System.Drawing.StringFormat
            $textFormat.Alignment = [System.Drawing.StringAlignment]::Center
            $textFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
            $textFormat.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
            $textFormat.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
            
            # 単独列（1行目にタイトル、2行目は空欄）
            if ($singleColumns) {
                foreach ($colName in $singleColumns) {
                    $col = $sender.Columns[$colName]
                    if (-not $col) { continue }
                    
                    $cellRect = $sender.GetCellDisplayRectangle($col.Index, -1, $true)
                    if ($cellRect.Width -le 0) { continue }
                    
                    # ヘッダー全体を塗りつぶし（1行目 + 2行目）
                    $fullRect = New-Object System.Drawing.RectangleF(
                        [float]($cellRect.Left + 1),
                        [float]($cellRect.Top + 1),
                        [float]($cellRect.Width - 1),
                        [float]($cellRect.Height - 1)
                    )
                    $graphics.FillRectangle($backBrush, $fullRect)
                    
                    # タイトルを中央に描画（2行分の高さで中央揃え）
                    $graphics.DrawString($col.HeaderText, $titleFont, $textBrush, $fullRect, $textFormat)
                    
                    # 右辺の縦罫線
                    $graphics.DrawLine($gridPen, [int]$cellRect.Right - 1, [int]$cellRect.Top, [int]$cellRect.Right - 1, [int]$cellRect.Bottom)
                }
            }
            
            # グループ化された列
            if ($headerGroups) {
                foreach ($group in $headerGroups) {
                    if (-not $group.Columns -or $group.Columns.Count -eq 0) { continue }
                    
                    $firstColName = $group.Columns[0]
                    $lastColName = $group.Columns[$group.Columns.Count - 1]
                    
                    $firstCol = $sender.Columns[$firstColName]
                    $lastCol = $sender.Columns[$lastColName]
                    
                    if (-not $firstCol -or -not $lastCol) { continue }
                    
                    $firstRect = $sender.GetCellDisplayRectangle($firstCol.Index, -1, $true)
                    $lastRect = $sender.GetCellDisplayRectangle($lastCol.Index, -1, $true)
                    
                    if ($firstRect.Width -le 0 -or $lastRect.Width -le 0) { continue }
                    
                    # グループヘッダー領域（1行目）
                    $groupRect = New-Object System.Drawing.RectangleF(
                        [float]($firstRect.Left + 1),
                        [float]($firstRect.Top + 1),
                        [float]($lastRect.Right - $firstRect.Left - 1),
                        [float]($groupHeight - 1)
                    )
                    
                    # 背景を塗る
                    $graphics.FillRectangle($backBrush, $groupRect)
                    
                    # グループタイトルを描画（折り返しなし）
                    $graphics.DrawString($group.Title, $titleFont, $textBrush, $groupRect, $textFormat)
                    
                    # 下辺（1行目と2行目の境界線）
                    $lineY = [int]($firstRect.Top + $groupHeight)
                    $graphics.DrawLine($gridPen, [int]$firstRect.Left, $lineY, [int]$lastRect.Right, $lineY)
                    
                    # 右辺の縦罫線
                    $graphics.DrawLine($gridPen, [int]$lastRect.Right - 1, [int]$firstRect.Top, [int]$lastRect.Right - 1, [int]$firstRect.Bottom)
                }
            }
            
            $textFormat.Dispose()
            $gridPen.Dispose()
            $titleFont.Dispose()
            $textBrush.Dispose()
            $backBrush.Dispose()
        }
        catch {
            # 描画エラーは無視
        }
    })

    # セル描画（データセルの選択色抑制）
    $dgv.Add_CellPainting({
        param($sender, $e)

        try {
            if ($e.RowIndex -ge 0 -and $e.ColumnIndex -ge 0) {
                $parts = $e.PaintParts
                if (($parts -band [System.Windows.Forms.DataGridViewPaintParts]::Focus) -ne 0) {
                    $parts = $parts -bxor [System.Windows.Forms.DataGridViewPaintParts]::Focus
                }
                if (($parts -band [System.Windows.Forms.DataGridViewPaintParts]::SelectionBackground) -ne 0) {
                    $parts = $parts -bxor [System.Windows.Forms.DataGridViewPaintParts]::SelectionBackground
                }

                $e.CellStyle.SelectionBackColor = $e.CellStyle.BackColor
                $e.CellStyle.SelectionForeColor = $e.CellStyle.ForeColor
                $e.Paint($e.CellBounds, $parts)
                $e.Handled = $true
            }
        }
        catch {
            # 描画エラーは無視
        }
    })

    # Add columns
    Add-ConnectionGridColumns -DataGridView $dgv

    return $dgv
}

function Add-ConnectionGridColumns {
    <#
    .SYNOPSIS
    Adds columns to the connection DataGridView.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.DataGridView]$DataGridView
    )

    # Name column
    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Name"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.FillWeight = 150
    [void]$DataGridView.Columns.Add($colName)

    # Protocol column
    $colProtocol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colProtocol.HeaderText = "Protocol"
    $colProtocol.Name = "Protocol"
    $colProtocol.ReadOnly = $true
    $colProtocol.FillWeight = 110
    [void]$DataGridView.Columns.Add($colProtocol)

    # Local Endpoint column
    $colLocalEndpoint = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colLocalEndpoint.HeaderText = "Local"
    $colLocalEndpoint.Name = "LocalEndpoint"
    $colLocalEndpoint.ReadOnly = $true
    $colLocalEndpoint.FillWeight = 120
    [void]$DataGridView.Columns.Add($colLocalEndpoint)

    # Remote Endpoint column
    $colRemoteEndpoint = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colRemoteEndpoint.HeaderText = "Remote"
    $colRemoteEndpoint.Name = "RemoteEndpoint"
    $colRemoteEndpoint.ReadOnly = $true
    $colRemoteEndpoint.FillWeight = 120
    [void]$DataGridView.Columns.Add($colRemoteEndpoint)

    # Status column
    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Status"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.FillWeight = 110
    [void]$DataGridView.Columns.Add($colStatus)

    # Connect button column
    $colConnect = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colConnect.HeaderText = "Connect"
    $colConnect.Name = "BtnConnect"
    $colConnect.Text = "▶"
    $colConnect.UseColumnTextForButtonValue = $true
    $colConnect.FillWeight = 80
    $colConnect.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
    $colConnect.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $colConnect.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(28, 151, 234)
    $colConnect.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    [void]$DataGridView.Columns.Add($colConnect)

    # Disconnect button column
    $colDisconnect = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colDisconnect.HeaderText = "Disconnect"
    $colDisconnect.Name = "BtnDisconnect"
    $colDisconnect.Text = "⏹"
    $colDisconnect.UseColumnTextForButtonValue = $true
    $colDisconnect.FillWeight = 90
    $colDisconnect.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(192, 57, 43)
    $colDisconnect.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $colDisconnect.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
    $colDisconnect.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    [void]$DataGridView.Columns.Add($colDisconnect)

    # Profile column
    $colProfile = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colProfile.HeaderText = "Profile"
    $colProfile.Name = "Profile"
    $colProfile.DisplayMember = "Display"
    $colProfile.ValueMember = "Key"
    $colProfile.ValueType = [string]
    $colProfile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colProfile.FillWeight = 130
    [void]$DataGridView.Columns.Add($colProfile)

    # On Receive: Reply column (ComboBox)
    $colOnReceiveReply = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnReceiveReply.HeaderText = "Reply"
    $colOnReceiveReply.Name = "Scenario"
    $colOnReceiveReply.DisplayMember = "Display"
    $colOnReceiveReply.ValueMember = "Key"
    $colOnReceiveReply.ValueType = [string]
    $colOnReceiveReply.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnReceiveReply.FillWeight = 140
    [void]$DataGridView.Columns.Add($colOnReceiveReply)

    # On Receive: Script column (ComboBox)
    $colOnReceiveScript = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnReceiveScript.HeaderText = "Script"
    $colOnReceiveScript.Name = "OnReceiveScript"
    $colOnReceiveScript.DisplayMember = "Display"
    $colOnReceiveScript.ValueMember = "Key"
    $colOnReceiveScript.ValueType = [string]
    $colOnReceiveScript.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnReceiveScript.FillWeight = 140
    [void]$DataGridView.Columns.Add($colOnReceiveScript)

    # On Timer: Send column (ComboBox)
    $colOnTimerSend = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnTimerSend.HeaderText = "Send"
    $colOnTimerSend.Name = "OnTimerSend"
    $colOnTimerSend.DisplayMember = "Display"
    $colOnTimerSend.ValueMember = "Key"
    $colOnTimerSend.ValueType = [string]
    $colOnTimerSend.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnTimerSend.FillWeight = 140
    [void]$DataGridView.Columns.Add($colOnTimerSend)

    # Manual: Send column (ComboBox)
    $colManualSend = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colManualSend.HeaderText = "Send"
    $colManualSend.Name = "ManualSend"
    $colManualSend.DisplayMember = "Display"
    $colManualSend.ValueMember = "Key"
    $colManualSend.ValueType = [string]
    $colManualSend.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colManualSend.FillWeight = 170
    [void]$DataGridView.Columns.Add($colManualSend)

    # Quick Send button column
    $colQuickSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colQuickSend.HeaderText = "Send"
    $colQuickSend.Name = "QuickSend"
    $colQuickSend.Text = "📤"
    $colQuickSend.UseColumnTextForButtonValue = $true
    $colQuickSend.FillWeight = 60
    $colQuickSend.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(39, 174, 96)
    $colQuickSend.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $colQuickSend.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
    $colQuickSend.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    [void]$DataGridView.Columns.Add($colQuickSend)

    # Manual: Script column (ComboBox)
    $colManualScript = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colManualScript.HeaderText = "Script"
    $colManualScript.Name = "ManualScript"
    $colManualScript.DisplayMember = "Display"
    $colManualScript.ValueMember = "Key"
    $colManualScript.ValueType = [string]
    $colManualScript.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colManualScript.FillWeight = 170
    [void]$DataGridView.Columns.Add($colManualScript)

    # Action Send button column
    $colActionSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colActionSend.HeaderText = "Run"
    $colActionSend.Name = "ActionSend"
    $colActionSend.Text = "▶"
    $colActionSend.UseColumnTextForButtonValue = $true
    $colActionSend.FillWeight = 55
    $colActionSend.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(142, 68, 173)
    $colActionSend.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $colActionSend.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(155, 89, 182)
    $colActionSend.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    [void]$DataGridView.Columns.Add($colActionSend)

    # Hidden Id column
    $colId = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colId.HeaderText = "Id"
    $colId.Name = "Id"
    $colId.ReadOnly = $true
    $colId.Visible = $false
    [void]$DataGridView.Columns.Add($colId)
}

function New-ToolbarButton {
    <#
    .SYNOPSIS
    Creates a toolbar button.
    #>
    param(
        [string]$Text,
        [int]$X,
        [int]$Y = 10,
        [int]$Width = 100,
        [int]$Height = 32,
        [string]$ToolTip = ""
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.Text = $Text
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    # ホバー効果
    $button.Add_MouseEnter({
        $this.BackColor = [System.Drawing.Color]::FromArgb(28, 151, 234)
    })
    $button.Add_MouseLeave({
        $this.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
    })
    
    # ツールチップを追加
    if ($ToolTip) {
        $toolTipObj = New-Object System.Windows.Forms.ToolTip
        $toolTipObj.SetToolTip($button, $ToolTip)
    }

    return $button
}

function New-LabelControl {
    <#
    .SYNOPSIS
    Creates a label control.
    #>
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 200,
        [int]$Height = 20,
        [bool]$Bold = $false
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.Text = $Text
    
    if ($Bold) {
        $label.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    }

    return $label
}

function New-RefreshTimer {
    <#
    .SYNOPSIS
    Creates a timer for periodic UI refresh.
    #>
    param(
        [int]$IntervalMilliseconds = 1000
    )

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $IntervalMilliseconds

    return $timer
}

function Configure-ProfileColumn {
    <#
    .SYNOPSIS
    Configures the Profile column cell for a connection row (Instance Profile selection).
    #>
    param(
        $Row,
        $Connection
    )

    $profileCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $profileCell.DisplayMember = "Display"
    $profileCell.ValueMember = "Key"
    $profileCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    $items = New-Object System.Collections.ArrayList
    $mapping = @{}

    $noneEntry = [PSCustomObject]@{
        Display = "(None)"
        Key     = ""
    }
    [void]$items.Add($noneEntry)
    $mapping[$noneEntry.Key] = $noneEntry

    # インスタンス名を取得
    $instanceName = ""
    if ($Connection -and $Connection.Variables -and $Connection.Variables.ContainsKey('InstanceName')) {
        $instanceName = $Connection.Variables['InstanceName']
    }

    $availableProfiles = @()
    if ($Global:ProfileService -and -not [string]::IsNullOrWhiteSpace($instanceName)) {
        try {
            $availableProfiles = $Global:ProfileService.GetAvailableInstanceProfiles($instanceName) | Sort-Object
            Write-Verbose "[ViewBuilder] Instance: $instanceName, Profiles: $($availableProfiles.Count)"
        }
        catch {
            Write-Verbose "[ViewBuilder] Failed to get profiles for $instanceName : $_"
            $availableProfiles = @()
        }
    } else {
        Write-Verbose "[ViewBuilder] ProfileService: $($null -ne $Global:ProfileService), InstanceName: '$instanceName'"
    }

    foreach ($name in $availableProfiles) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $entry = [PSCustomObject]@{
            Display = $name
            Key     = $name
        }
        [void]$items.Add($entry)
        $mapping[$entry.Key] = $entry
    }

    $currentProfile = ""
    if ($Connection -and $Connection.Variables -and $Connection.Variables.ContainsKey('InstanceProfile')) {
        $currentProfile = [string]$Connection.Variables['InstanceProfile']
        if (-not [string]::IsNullOrWhiteSpace($currentProfile) -and -not $mapping.ContainsKey($currentProfile)) {
            $entry = [PSCustomObject]@{
                Display = "$currentProfile (missing)"
                Key     = $currentProfile
            }
            [void]$items.Add($entry)
            $mapping[$entry.Key] = $entry
        }
    }

    foreach ($item in $items) {
        [void]$profileCell.Items.Add($item)
    }

    $profileCell.Value = if ($currentProfile) { $currentProfile } else { "" }
    $profileCell.Tag = @{ Mapping = $mapping }

    $Row.Cells["Profile"] = $profileCell
}

function Configure-ScenarioColumn {
    <#
    .SYNOPSIS
    Configures the Scenario (On Receive: Reply) column cell for a connection row.
    #>
    param(
        $Row,
        $Connection,
        [string]$InstancePath
    )

    $items = New-Object System.Collections.ArrayList
    $mapping = @{}
    $availableScenarios = @()

    $noneEntry = [PSCustomObject]@{
        Display = "(None)"
        Key     = ""
        Type    = "Profile"
        Name    = $null
        Path    = $null
    }
    [void]$items.Add($noneEntry)
    $mapping[$noneEntry.Key] = $noneEntry

    $currentProfile = ""
    $currentPath = $null
    if ($Connection.Variables.ContainsKey('OnReceiveReplyProfile')) {
        $currentProfile = $Connection.Variables['OnReceiveReplyProfile']
    }
    if ($Connection.Variables.ContainsKey('OnReceiveReplyProfilePath')) {
        $currentPath = $Connection.Variables['OnReceiveReplyProfilePath']
    }

    # Add profiles
    $profiles = @()
    if ($InstancePath) {
        try {
            $profiles = Get-InstanceOnReceiveReplyProfiles -InstancePath $InstancePath
        } catch {
            $profiles = @()
        }
    }

    foreach ($profile in $profiles) {
        if ([string]::IsNullOrWhiteSpace($profile.Name)) { continue }

        $key = "profile::$($profile.Name)"
        $entry = [PSCustomObject]@{
            Display = $profile.DisplayName
            Key     = $key
            Type    = "Profile"
            Name    = $profile.Name
            Path    = $profile.FilePath
        }
        [void]$items.Add($entry)
        $mapping[$key] = $entry
    }

    # Add scenarios
    if ($InstancePath) {
        try {
            $scenarioFiles = Get-InstanceScenarios -InstancePath $InstancePath
        } catch {
            $scenarioFiles = @()
        }

        if ($scenarioFiles -and $scenarioFiles.Count -gt 0) {
            $scenarioRoot = Join-Path $InstancePath "scenarios"
            foreach ($scenario in $scenarioFiles) {
                $scenarioKey = "scenario::$scenario"
                $scenarioPath = Join-Path $scenarioRoot $scenario
                $entry = [PSCustomObject]@{
                    Display = "? $scenario"
                    Key     = $scenarioKey
                    Type    = "Scenario"
                    Name    = $scenario
                    Path    = $scenarioPath
                }
                [void]$items.Add($entry)
                $mapping[$scenarioKey] = $entry
                $availableScenarios += $entry
            }
        }
    }

    $currentKey = ""
    if ($currentProfile) {
        $currentKey = "profile::$currentProfile"
        if (-not $mapping.ContainsKey($currentKey)) {
            $displayName = if ($currentPath) { "$currentProfile (missing)" } else { $currentProfile }
            $entry = [PSCustomObject]@{
                Display = $displayName
                Key     = $currentKey
                Type    = "Profile"
                Name    = $currentProfile
                Path    = $currentPath
            }
            [void]$items.Add($entry)
            $mapping[$currentKey] = $entry
        }
    }

    $scenarioCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $scenarioCell.DisplayMember = "Display"
    $scenarioCell.ValueMember = "Key"
    foreach ($item in $items) {
        [void]$scenarioCell.Items.Add($item)
    }
    $scenarioCell.Value = $currentKey
    $scenarioCell.Tag = @{
        Mapping            = $mapping
        ProfileKey         = $currentKey
        AvailableScenarios = $availableScenarios
    }
    $Row.Cells["Scenario"] = $scenarioCell
}

function Configure-OnReceiveScriptColumn {
    <#
    .SYNOPSIS
    Configures the On Receive: Script column cell for a connection row.
    #>
    param(
        $Row,
        $Connection,
        [string]$InstancePath
    )

    $onReceiveScriptItems = New-Object System.Collections.ArrayList
    $onReceiveScriptMapping = @{}

    $onReceiveScriptNone = [PSCustomObject]@{
        Display = "(None)"
        Key     = ""
        Type    = "Profile"
        Name    = $null
        Path    = $null
    }
    [void]$onReceiveScriptItems.Add($onReceiveScriptNone)
    $onReceiveScriptMapping[$onReceiveScriptNone.Key] = $onReceiveScriptNone

    $currentOnReceiveScriptProfile = ""
    $currentOnReceiveScriptPath = $null
    if ($Connection.Variables.ContainsKey('OnReceiveScriptProfile')) {
        $currentOnReceiveScriptProfile = $Connection.Variables['OnReceiveScriptProfile']
    }
    if ($Connection.Variables.ContainsKey('OnReceiveScriptProfilePath')) {
        $currentOnReceiveScriptPath = $Connection.Variables['OnReceiveScriptProfilePath']
    }

    $onReceiveScriptProfiles = @()
    if ($InstancePath) {
        try {
            $onReceiveScriptProfiles = Get-InstanceOnReceiveScriptProfiles -InstancePath $InstancePath
        } catch {
            $onReceiveScriptProfiles = @()
        }
    }

    foreach ($prof in $onReceiveScriptProfiles) {
        if ([string]::IsNullOrWhiteSpace($prof.Name)) { continue }

        $key = "onreceivescript::$($prof.Name)"
        $entry = [PSCustomObject]@{
            Display = $prof.DisplayName
            Key     = $key
            Type    = "Profile"
            Name    = $prof.Name
            Path    = $prof.FilePath
        }
        [void]$onReceiveScriptItems.Add($entry)
        $onReceiveScriptMapping[$key] = $entry
    }

    $currentOnReceiveScriptKey = ""
    if ($currentOnReceiveScriptProfile) {
        $currentOnReceiveScriptKey = "onreceivescript::$currentOnReceiveScriptProfile"
        if (-not $onReceiveScriptMapping.ContainsKey($currentOnReceiveScriptKey)) {
            $displayName = if ($currentOnReceiveScriptPath) { "$currentOnReceiveScriptProfile (missing)" } else { $currentOnReceiveScriptProfile }
            $entry = [PSCustomObject]@{
                Display = $displayName
                Key     = $currentOnReceiveScriptKey
                Type    = "Profile"
                Name    = $currentOnReceiveScriptProfile
                Path    = $currentOnReceiveScriptPath
            }
            [void]$onReceiveScriptItems.Add($entry)
            $onReceiveScriptMapping[$currentOnReceiveScriptKey] = $entry
        }
    }

    $onReceiveScriptCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $onReceiveScriptCell.DisplayMember = "Display"
    $onReceiveScriptCell.ValueMember = "Key"
    foreach ($item in $onReceiveScriptItems) {
        [void]$onReceiveScriptCell.Items.Add($item)
    }
    $onReceiveScriptCell.Value = $currentOnReceiveScriptKey
    $onReceiveScriptCell.Tag = @{
        Mapping                    = $onReceiveScriptMapping
        OnReceiveScriptProfileKey  = $currentOnReceiveScriptKey
    }
    $Row.Cells["OnReceiveScript"] = $onReceiveScriptCell
}

function Configure-OnTimerSendColumn {
    <#
    .SYNOPSIS
    Configures the On Timer: Send column cell for a connection row.
    #>
    param(
        $Row,
        $Connection,
        [string]$InstancePath
    )

    $currentOnTimerSendProfile = ""
    $currentOnTimerSendPath = $null
    if ($Connection.Variables.ContainsKey('OnTimerSendProfile')) {
        $currentOnTimerSendProfile = $Connection.Variables['OnTimerSendProfile']
    }
    if ($Connection.Variables.ContainsKey('OnTimerSendProfilePath')) {
        $currentOnTimerSendPath = $Connection.Variables['OnTimerSendProfilePath']
    }

    $onTimerSendProfiles = @()
    if ($InstancePath) {
        try {
            $onTimerSendProfiles = Get-InstanceOnTimerSendProfiles -InstancePath $InstancePath
        } catch {
            $onTimerSendProfiles = @()
        }
    }

    $onTimerSendItems = New-Object System.Collections.ArrayList
    $onTimerSendMapping = @{}
    
    $onTimerSendPlaceholder = [PSCustomObject]@{
        Display = "(None)"
        Key     = ""
        Type    = "None"
        Name    = $null
        Path    = $null
    }
    [void]$onTimerSendItems.Add($onTimerSendPlaceholder)
    $onTimerSendMapping[$onTimerSendPlaceholder.Key] = $onTimerSendPlaceholder

    foreach ($prof in $onTimerSendProfiles) {
        $key = "ontimersend::$($prof.ProfileName)"
        $entry = [PSCustomObject]@{
            Display = $prof.ProfileName
            Key     = $key
            Type    = "Profile"
            Name    = $prof.ProfileName
            Path    = $prof.FilePath
        }
        [void]$onTimerSendItems.Add($entry)
        $onTimerSendMapping[$key] = $entry
    }

    $currentOnTimerSendKey = ""
    if ($currentOnTimerSendProfile) {
        $currentOnTimerSendKey = "ontimersend::$currentOnTimerSendProfile"
        if (-not $onTimerSendMapping.ContainsKey($currentOnTimerSendKey)) {
            $displayName = if ($currentOnTimerSendPath) { "$currentOnTimerSendProfile (missing)" } else { $currentOnTimerSendProfile }
            $entry = [PSCustomObject]@{
                Display = $displayName
                Key     = $currentOnTimerSendKey
                Type    = "Profile"
                Name    = $currentOnTimerSendProfile
                Path    = $currentOnTimerSendPath
            }
            [void]$onTimerSendItems.Add($entry)
            $onTimerSendMapping[$currentOnTimerSendKey] = $entry
        }
    }

    $onTimerSendCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $onTimerSendCell.DisplayMember = "Display"
    $onTimerSendCell.ValueMember = "Key"
    foreach ($item in $onTimerSendItems) {
        [void]$onTimerSendCell.Items.Add($item)
    }
    $onTimerSendCell.Value = $currentOnTimerSendKey
    $onTimerSendCell.Tag = @{
        Mapping               = $onTimerSendMapping
        OnTimerSendProfileKey = $currentOnTimerSendKey
    }
    $Row.Cells["OnTimerSend"] = $onTimerSendCell
}

function Configure-ManualSendColumn {
    <#
    .SYNOPSIS
    Configures the Manual: Send column cell for a connection row.
    #>
    param(
        $Row,
        [string]$InstancePath
    )

    $dataBankEntries = @()
    $dataBankPath = $null
    if ($InstancePath) {
        try {
            $catalog = Get-ManualSendCatalog -InstancePath $InstancePath
            if ($catalog) {
                $dataBankEntries = if ($catalog.Entries) { $catalog.Entries } else { @() }
                $dataBankPath = $catalog.Path
            }
        } catch {
            $dataBankEntries = @()
        }
    }

    $manualSendCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $manualSendCell.DisplayMember = "Display"
    $manualSendCell.ValueMember = "Key"
    $manualSendCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    $dataSource = New-Object System.Collections.ArrayList
    $dataPlaceholder = [PSCustomObject]@{
        Display = "(Select)"
        Key     = ""
    }
    [void]$dataSource.Add($dataPlaceholder)

    if ($dataBankEntries -and $dataBankEntries.Count -gt 0) {
        foreach ($item in $dataBankEntries) {
            if (-not $item.DataID) { continue }

            $displayText = if ([string]::IsNullOrWhiteSpace($item.Description)) {
                $item.DataID
            } else {
                "{0} - {1}" -f $item.DataID, $item.Description
            }

            $entry = [PSCustomObject]@{
                Display = $displayText
                Key     = [string]$item.DataID
            }
            [void]$dataSource.Add($entry)
        }
    }

    foreach ($item in $dataSource) {
        [void]$manualSendCell.Items.Add($item)
    }
    $manualSendCell.Value = ""
    $manualSendCell.Tag = @{
        DataBankCount = $dataBankEntries.Count
        DataBankPath  = if ($dataBankPath -and (Test-Path -LiteralPath $dataBankPath)) { $dataBankPath } else { $null }
    }
    $Row.Cells["ManualSend"] = $manualSendCell
}

function Configure-ManualScriptColumn {
    <#
    .SYNOPSIS
    Configures the Manual: Script column cell for a connection row.
    #>
    param(
        $Row,
        [string]$InstancePath
    )

    $manualScriptCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $manualScriptCell.DisplayMember = "Display"
    $manualScriptCell.ValueMember = "Key"
    $manualScriptCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    $actionSource = New-Object System.Collections.ArrayList
    $actionMapping = @{}
    $actionPlaceholder = [PSCustomObject]@{
        Display = "(Select)"
        Key     = ""
        Type    = ""
        Path    = $null
        Name    = $null
    }
    [void]$actionSource.Add($actionPlaceholder)
    $actionMapping[$actionPlaceholder.Key] = $actionPlaceholder

    # Get available scenarios from Scenario column
    $scenarioCell = $Row.Cells["Scenario"]
    $availableScenarios = @()
    if ($scenarioCell.Tag -is [System.Collections.IDictionary] -and $scenarioCell.Tag.ContainsKey("AvailableScenarios")) {
        $availableScenarios = $scenarioCell.Tag["AvailableScenarios"]
    }

    foreach ($scenarioEntry in $availableScenarios) {
        $actionEntry = [PSCustomObject]@{
            Display = $scenarioEntry.Display
            Key     = $scenarioEntry.Key
            Type    = $scenarioEntry.Type
            Path    = $scenarioEntry.Path
            Name    = $scenarioEntry.Name
        }
        [void]$actionSource.Add($actionEntry)
        $actionMapping[$actionEntry.Key] = $actionEntry
    }

    foreach ($item in $actionSource) {
        [void]$manualScriptCell.Items.Add($item)
    }
    $manualScriptCell.Value = ""
    $manualScriptCell.Tag = @{
        Mapping = $actionMapping
    }
    $Row.Cells["ManualScript"] = $manualScriptCell
}

function Set-RowColor {
    <#
    .SYNOPSIS
    Sets the background color of a row based on connection status.
    #>
    param(
        $Row,
        [string]$Status
    )

    switch ($Status) {
        "CONNECTED" {
            # より洗練された緑色
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(220, 255, 220)
            $Row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(0, 100, 0)
        }
        "CONNECTING" {
            # より洗練された黄色
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 205)
            $Row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(139, 115, 0)
        }
        "ERROR" {
            # より洗練された赤色
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255, 220, 220)
            $Row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(139, 0, 0)
        }
        "DISCONNECTED" {
            # より洗練されたグレー
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
            $Row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
        }
        default {
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
            $Row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        }
    }
}

function Get-MessageSummary {
    <#
    .SYNOPSIS
    Generates a summary string from binary message data.
    #>
    param(
        [byte[]]$Data,
        [int]$MaxLength = 40
    )

    if (-not $Data -or $Data.Length -eq 0) {
        return "(empty)"
    }

    $isPrintable = $true
    $hexStr = ($Data | ForEach-Object { $_.ToString("X2") }) -join " "
    foreach ($byte in $Data) {
        if ($byte -lt 32 -or $byte -gt 126) {
            $isPrintable = $false
            break
        }
    }

    if ($isPrintable) {
        $text = [System.Text.Encoding]::ASCII.GetString($Data)
        $text = $text -replace "`r", "" -replace "`n", " " -replace "`t", " "
        if ($text.Length -gt $MaxLength) {
            return $text.Substring(0, $MaxLength) + "..."
        }
        return $text
    } else {
        if ($hexStr.Length -gt $MaxLength) {
            return $hexStr.Substring(0, $MaxLength) + "..."
        }
        return $hexStr
    }
}

function New-StyledComboBox {
    <#
    .SYNOPSIS
    Creates a styled ComboBox with modern appearance.
    #>
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 200,
        [int]$Height = 25,
        [string]$ToolTip = ""
    )

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point($X, $Y)
    $comboBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboBox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $comboBox.BackColor = [System.Drawing.Color]::White
    $comboBox.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    
    if ($ToolTip) {
        $toolTipObj = New-Object System.Windows.Forms.ToolTip
        $toolTipObj.SetToolTip($comboBox, $ToolTip)
    }

    return $comboBox
}

function New-StatusLabel {
    <#
    .SYNOPSIS
    Creates a status label for displaying application status.
    #>
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 400,
        [int]$Height = 20,
        [string]$InitialText = "Ready"
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.Text = $InitialText
    $label.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $label.AutoSize = $false

    return $label
}

# Note: Export-ModuleMember is not needed when dot-sourcing.
# If this file is imported as a module, uncomment the following:
# Export-ModuleMember -Function @(
#     'New-MainFormWindow',
#     'New-ConnectionDataGridView',
#     'New-ToolbarButton',
#     'New-LabelControl',
#     'New-RefreshTimer',
#     'New-StyledComboBox',
#     'New-StatusLabel',
#     'Configure-ScenarioColumn',
#     'Configure-OnReceiveScriptColumn',
#     'Configure-OnTimerSendColumn',
#     'Configure-ManualSendColumn',
#     'Configure-ManualScriptColumn',
#     'Set-RowColor',
#     'Get-MessageSummary'
# )
