# MainForm.ps1
# WinForms main window definition

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-MainForm {
    <#
    .SYNOPSIS
    Show the main WinForms UI.
    #>

    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "TCP Test Controller v1.0"
    $form.Size = New-Object System.Drawing.Size(1200, 700)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $script:CurrentMainForm = $form

    # DataGridView (connection list)
    $dgvInstances = New-Object System.Windows.Forms.DataGridView
    $dgvInstances.Location = New-Object System.Drawing.Point(10, 50)
    $dgvInstances.Size = New-Object System.Drawing.Size(1165, 230)
    $dgvInstances.AllowUserToAddRows = $false
    $dgvInstances.AllowUserToDeleteRows = $false
    $dgvInstances.AllowUserToResizeRows = $false
    $dgvInstances.RowHeadersVisible = $false
    $dgvInstances.ReadOnly = $false
    $dgvInstances.SelectionMode = "FullRowSelect"
    $dgvInstances.MultiSelect = $false
    $dgvInstances.AutoSizeColumnsMode = "Fill"
    $dgvInstances.AutoGenerateColumns = $false

    # Columns
    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.HeaderText = "Name"
    $colName.Name = "Name"
    $colName.ReadOnly = $true
    $colName.FillWeight = 150
    $dgvInstances.Columns.Add($colName) | Out-Null

    $colProtocol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colProtocol.HeaderText = "Protocol"
    $colProtocol.Name = "Protocol"
    $colProtocol.ReadOnly = $true
    $colProtocol.FillWeight = 110
    $dgvInstances.Columns.Add($colProtocol) | Out-Null

    $colEndpoint = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colEndpoint.HeaderText = "Endpoint"
    $colEndpoint.Name = "Endpoint"
    $colEndpoint.ReadOnly = $true
    $colEndpoint.FillWeight = 160
    $dgvInstances.Columns.Add($colEndpoint) | Out-Null

    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Status"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.FillWeight = 100
    $dgvInstances.Columns.Add($colStatus) | Out-Null

    $colAutoResponse = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colAutoResponse.HeaderText = "Auto Response"
    $colAutoResponse.Name = "Scenario"
    $colAutoResponse.DisplayMember = "Display"
    $colAutoResponse.ValueMember = "Key"
    $colAutoResponse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colAutoResponse.FillWeight = 140
    $dgvInstances.Columns.Add($colAutoResponse) | Out-Null

    $colOnReceived = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnReceived.HeaderText = "On Received"
    $colOnReceived.Name = "OnReceived"
    $colOnReceived.DisplayMember = "Display"
    $colOnReceived.ValueMember = "Key"
    $colOnReceived.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnReceived.FillWeight = 140
    $dgvInstances.Columns.Add($colOnReceived) | Out-Null

    $colPeriodicSend = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colPeriodicSend.HeaderText = "Periodic Send"
    $colPeriodicSend.Name = "PeriodicSend"
    $colPeriodicSend.DisplayMember = "Display"
    $colPeriodicSend.ValueMember = "Key"
    $colPeriodicSend.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colPeriodicSend.FillWeight = 140
    $dgvInstances.Columns.Add($colPeriodicSend) | Out-Null

    $colQuickData = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colQuickData.HeaderText = "Quick Data"
    $colQuickData.Name = "QuickData"
    $colQuickData.DisplayMember = "Display"
    $colQuickData.ValueMember = "Key"
    $colQuickData.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colQuickData.FillWeight = 170
    $dgvInstances.Columns.Add($colQuickData) | Out-Null

    $colQuickSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colQuickSend.HeaderText = "Send"
    $colQuickSend.Name = "QuickSend"
    $colQuickSend.Text = "Send"
    $colQuickSend.UseColumnTextForButtonValue = $true
    $colQuickSend.FillWeight = 70
    $dgvInstances.Columns.Add($colQuickSend) | Out-Null

    $colQuickAction = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colQuickAction.HeaderText = "Quick Action"
    $colQuickAction.Name = "QuickAction"
    $colQuickAction.DisplayMember = "Display"
    $colQuickAction.ValueMember = "Key"
    $colQuickAction.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colQuickAction.FillWeight = 170
    $dgvInstances.Columns.Add($colQuickAction) | Out-Null

    $colActionSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colActionSend.HeaderText = "Run"
    $colActionSend.Name = "ActionSend"
    $colActionSend.Text = "Run"
    $colActionSend.UseColumnTextForButtonValue = $true
    $colActionSend.FillWeight = 70
    $dgvInstances.Columns.Add($colActionSend) | Out-Null

    $colId = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colId.HeaderText = "Id"
    $colId.Name = "Id"
    $colId.ReadOnly = $true
    $colId.Visible = $false
    $dgvInstances.Columns.Add($colId) | Out-Null

    $form.Controls.Add($dgvInstances)

    # Toolbar buttons
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Location = New-Object System.Drawing.Point(10, 10)
    $btnRefresh.Size = New-Object System.Drawing.Size(100, 30)
    $btnRefresh.Text = "Refresh"
    $form.Controls.Add($btnRefresh)

    $btnConnect = New-Object System.Windows.Forms.Button
    $btnConnect.Location = New-Object System.Drawing.Point(120, 10)
    $btnConnect.Size = New-Object System.Drawing.Size(100, 30)
    $btnConnect.Text = "Connect"
    $form.Controls.Add($btnConnect)

    $btnDisconnect = New-Object System.Windows.Forms.Button
    $btnDisconnect.Location = New-Object System.Drawing.Point(230, 10)
    $btnDisconnect.Size = New-Object System.Drawing.Size(100, 30)
    $btnDisconnect.Text = "Disconnect"
    $form.Controls.Add($btnDisconnect)

    # Log area
    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Location = New-Object System.Drawing.Point(10, 290)
    $lblLog.Size = New-Object System.Drawing.Size(200, 20)
    $lblLog.Text = "Connection Log:"
    $form.Controls.Add($lblLog)

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Location = New-Object System.Drawing.Point(10, 315)
    $txtLog.Size = New-Object System.Drawing.Size(1165, 335)
    $txtLog.Multiline = $true
    $txtLog.ScrollBars = "Vertical"
    $txtLog.ReadOnly = $true
    $txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
    $form.Controls.Add($txtLog)

    # State holders
    $suppressScenarioEvent = $false

    $getSelectedConnection = {
        if ($dgvInstances.SelectedRows.Count -eq 0) {
            return $null
        }

        if (-not $dgvInstances.Columns.Contains("Id")) {
            return $null
        }

        $connId = $dgvInstances.SelectedRows[0].Cells["Id"].Value
        if (-not $connId) {
            return $null
        }

        if ($Global:Connections.ContainsKey($connId)) {
            return $Global:Connections[$connId]
        }

        return $null
    }

    # Events
    $btnRefresh.Add_Click({
        Update-InstanceList -DataGridView $dgvInstances
    })

    $btnConnect.Add_Click({
        if ($dgvInstances.SelectedRows.Count -eq 0) {
            return
        }

        $connId = $dgvInstances.SelectedRows[0].Cells["Id"].Value
        if (-not $connId) {
            return
        }

        if ($Global:Connections.ContainsKey($connId)) {
            $conn = $Global:Connections[$connId]
            try {
                Start-Connection -ConnectionId $conn.Id
                [System.Windows.Forms.MessageBox]::Show("Connection started: $($conn.DisplayName)", "Success") | Out-Null
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to start connection: $_", "Error") | Out-Null
            }

            Update-InstanceList -DataGridView $dgvInstances
        }
    })

    $btnDisconnect.Add_Click({
        if ($dgvInstances.SelectedRows.Count -eq 0) {
            return
        }

        $connId = $dgvInstances.SelectedRows[0].Cells["Id"].Value
        if (-not $connId) {
            return
        }

        if ($Global:Connections.ContainsKey($connId)) {
            $conn = $Global:Connections[$connId]
            try {
                Stop-Connection -ConnectionId $conn.Id
                [System.Windows.Forms.MessageBox]::Show("Connection stopped: $($conn.DisplayName)", "Success") | Out-Null
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to stop connection: $_", "Error") | Out-Null
            }

            Update-InstanceList -DataGridView $dgvInstances
        }
    })

    $dgvInstances.Add_CurrentCellDirtyStateChanged({
        if ($dgvInstances.IsCurrentCellDirty -and $dgvInstances.CurrentCell -and
            $dgvInstances.CurrentCell.OwningColumn -and
            $dgvInstances.CurrentCell.OwningColumn.Name -eq "Scenario") {
            $dgvInstances.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })

    $dgvInstances.Add_CellValueChanged({
        param($sender, $args)

        if ($suppressScenarioEvent) {
            return
        }

        if ($args.ColumnIndex -lt 0 -or $args.RowIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if ($column.Name -ne "Scenario") {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
        if (-not $row.Cells.Contains("Id")) {
            return
        }

        $connId = $row.Cells["Id"].Value
        if (-not $connId) {
            return
        }

        $cell = $row.Cells["Scenario"]
        $tagData = $cell.Tag
        $mapping = $null
        $currentProfileKey = ""

        if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping") -and $tagData.ContainsKey("ProfileKey")) {
            $mapping = $tagData["Mapping"]
            $currentProfileKey = $tagData["ProfileKey"]
        } elseif ($tagData -is [System.Collections.IDictionary]) {
            $mapping = $tagData
        }

        $selectedKey = if ($cell.Value) { [string]$cell.Value } else { "" }
        $entry = $null
        if ($mapping -and $mapping.ContainsKey($selectedKey)) {
            $entry = $mapping[$selectedKey]
        }

        if ($entry -and $entry.Type -eq "Scenario") {
            $scenarioPath = $entry.Path
            if (-not $scenarioPath -or -not (Test-Path -LiteralPath $scenarioPath)) {
                [System.Windows.Forms.MessageBox]::Show("Scenario file not found: $($entry.Name)", "Warning") | Out-Null
            } else {
                try {
                    Start-Scenario -ConnectionId $connId -ScenarioPath $scenarioPath
                    [System.Windows.Forms.MessageBox]::Show("Scenario started: $($entry.Name)", "Success") | Out-Null
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to start scenario: $_", "Error") | Out-Null
                }
            }

            if ($currentProfileKey -ne $selectedKey) {
                $suppressScenarioEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $suppressScenarioEvent = $false
                }
                $sender.InvalidateCell($cell)
            }

            return
        }

        $profileName = $null
        $profilePath = $null
        if ($entry -and $entry.Type -eq "Profile") {
            $profileName = $entry.Name
            $profilePath = $entry.Path
        }

        try {
            Set-ConnectionAutoResponseProfile -ConnectionId $connId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
            if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("ProfileKey")) {
                $tagData["ProfileKey"] = $selectedKey
            }
        } catch {
            if ($currentProfileKey -ne $selectedKey) {
                $suppressScenarioEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $suppressScenarioEvent = $false
                }
                $sender.InvalidateCell($cell)
            }
            [System.Windows.Forms.MessageBox]::Show("Failed to apply auto-response profile: $_", "Error") | Out-Null
        }
    })

    $dgvInstances.Add_CellValueChanged({
        param($sender, $args)

        if ($script:suppressOnReceivedEvent) {
            return
        }

        if ($args.RowIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if (-not $column -or $column.Name -ne "OnReceived") {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
        $cell = $row.Cells[$args.ColumnIndex]
        $connId = $row.Cells["Id"].Value

        if (-not $connId -or -not $Global:Connections.ContainsKey($connId)) {
            return
        }

        $tagData = $row.Tag
        $currentProfileKey = if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnReceivedProfileKey")) {
            $tagData["OnReceivedProfileKey"]
        } else {
            $null
        }

        $selectedKey = $cell.Value
        if ($selectedKey -eq $currentProfileKey) {
            return
        }

        $conn = $Global:Connections[$connId]
        $dataSource = $cell.OwningColumn.DataSource
        $entry = $dataSource | Where-Object { $_.Key -eq $selectedKey } | Select-Object -First 1

        $profileName = $null
        $profilePath = $null
        if ($entry -and $entry.Type -eq "Profile") {
            $profileName = $entry.Name
            $profilePath = $entry.Path
        }

        try {
            Set-ConnectionOnReceivedProfile -ConnectionId $connId -ProfileName $profileName -ProfilePath $profilePath | Out-Null
            if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("OnReceivedProfileKey")) {
                $tagData["OnReceivedProfileKey"] = $selectedKey
            }
        } catch {
            if ($currentProfileKey -ne $selectedKey) {
                $suppressOnReceivedEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $suppressOnReceivedEvent = $false
                }
                $sender.InvalidateCell($cell)
            }
            [System.Windows.Forms.MessageBox]::Show("Failed to apply OnReceived profile: $_", "Error") | Out-Null
        }
    })

    # Periodic Send profile change handler
    $dgvInstances.Add_CellValueChanged({
        param($sender, $args)

        if ($script:suppressPeriodicSendEvent) {
            return
        }

        if ($args.RowIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if (-not $column -or $column.Name -ne "PeriodicSend") {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
        $cell = $row.Cells[$args.ColumnIndex]
        $connId = $row.Cells["Id"].Value

        if (-not $connId -or -not $Global:Connections.ContainsKey($connId)) {
            return
        }

        $tagData = $row.Tag
        $currentProfileKey = if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("PeriodicSendProfileKey")) {
            $tagData["PeriodicSendProfileKey"]
        } else {
            $null
        }

        $selectedKey = $cell.Value
        if ($selectedKey -eq $currentProfileKey) {
            return
        }

        $conn = $Global:Connections[$connId]
        $dataSource = $cell.OwningColumn.DataSource
        $entry = $dataSource | Where-Object { $_.Key -eq $selectedKey } | Select-Object -First 1

        $profilePath = $null
        if ($entry -and $entry.Type -eq "Profile") {
            $profilePath = $entry.Path
        }

        try {
            $instancePath = Get-InstancePath -InstanceName $conn.InstanceName
            Set-ConnectionPeriodicSendProfile -ConnectionId $connId -ProfilePath $profilePath -InstancePath $instancePath | Out-Null
            if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("PeriodicSendProfileKey")) {
                $tagData["PeriodicSendProfileKey"] = $selectedKey
            }
        } catch {
            if ($currentProfileKey -ne $selectedKey) {
                $suppressPeriodicSendEvent = $true
                try {
                    $cell.Value = $currentProfileKey
                } finally {
                    $suppressPeriodicSendEvent = $false
                }
                $sender.InvalidateCell($cell)
            }
            [System.Windows.Forms.MessageBox]::Show("Failed to apply Periodic Send profile: $_", "Error") | Out-Null
        }
    })

    $dgvInstances.Add_CellContentClick({
        param($sender, $args)

        if ($args.RowIndex -lt 0 -or $args.ColumnIndex -lt 0) {
            return
        }

        $column = $sender.Columns[$args.ColumnIndex]
        if (-not $column) {
            return
        }

        $row = $sender.Rows[$args.RowIndex]
        if (-not $row.Cells.Contains("Id")) {
            return
        }

        $connId = $row.Cells["Id"].Value
        if (-not $connId) {
            return
        }

        $connection = $null
        if ($Global:Connections.ContainsKey($connId)) {
            $connection = $Global:Connections[$connId]
        }

        switch ($column.Name) {
            "QuickSend" {
                $comboCell = $row.Cells["QuickData"]
                if (-not $comboCell) { return }

                $selectedKey = if ($comboCell.Value) { [string]$comboCell.Value } else { "" }
                if ([string]::IsNullOrWhiteSpace($selectedKey)) {
                    [System.Windows.Forms.MessageBox]::Show("Please select a data item to send.", "Warning") | Out-Null
                    return
                }

                $tagData = $comboCell.Tag
                $dataBankPath = $null
                $dataBankCount = 0
                if ($tagData -is [System.Collections.IDictionary]) {
                    if ($tagData.ContainsKey("DataBankPath")) {
                        $dataBankPath = $tagData["DataBankPath"]
                    }
                    if ($tagData.ContainsKey("DataBankCount")) {
                        $dataBankCount = [int]$tagData["DataBankCount"]
                    }
                }

                if ($dataBankCount -le 0 -and [string]::IsNullOrWhiteSpace($dataBankPath)) {
                    [System.Windows.Forms.MessageBox]::Show("No data bank entries available for this connection.", "Warning") | Out-Null
                    return
                }

                if ($dataBankPath -and -not (Test-Path -LiteralPath $dataBankPath)) {
                    [System.Windows.Forms.MessageBox]::Show("Data bank file not found: $dataBankPath", "Warning") | Out-Null
                    return
                }

                try {
                    Send-QuickData -ConnectionId $connId -DataID $selectedKey -DataBankPath $dataBankPath
                    $targetName = if ($connection) { $connection.DisplayName } else { $connId }
                    [System.Windows.Forms.MessageBox]::Show("Sent data item '$selectedKey' to $targetName.", "Success") | Out-Null
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to send data: $_", "Error") | Out-Null
                }
            }
            "ActionSend" {
                $actionCell = $row.Cells["QuickAction"]
                if (-not $actionCell) { return }

                $selectedKey = if ($actionCell.Value) { [string]$actionCell.Value } else { "" }
                if ([string]::IsNullOrWhiteSpace($selectedKey)) {
                    [System.Windows.Forms.MessageBox]::Show("Please select an action to run.", "Warning") | Out-Null
                    return
                }

                $tagData = $actionCell.Tag
                $actionMapping = $null
                if ($tagData -is [System.Collections.IDictionary] -and $tagData.ContainsKey("Mapping")) {
                    $actionMapping = $tagData["Mapping"]
                }

                if (-not $actionMapping -or -not $actionMapping.ContainsKey($selectedKey)) {
                    [System.Windows.Forms.MessageBox]::Show("Selected action is not available.", "Warning") | Out-Null
                    return
                }

                $actionEntry = $actionMapping[$selectedKey]
                if ($actionEntry.Type -eq "Scenario") {
                    $scenarioPath = $actionEntry.Path
                    if (-not $scenarioPath -or -not (Test-Path -LiteralPath $scenarioPath)) {
                        [System.Windows.Forms.MessageBox]::Show("Scenario file not found.", "Warning") | Out-Null
                        return
                    }

                    try {
                        Start-Scenario -ConnectionId $connId -ScenarioPath $scenarioPath
                        $actionName = if ($actionEntry.Name) { $actionEntry.Name } else { $selectedKey }
                        [System.Windows.Forms.MessageBox]::Show("Started scenario '$actionName'.", "Success") | Out-Null
                    } catch {
                        [System.Windows.Forms.MessageBox]::Show("Failed to start scenario: $_", "Error") | Out-Null
                    }
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Selected action is not supported.", "Warning") | Out-Null
                }
            }
        }
    })

    # Timer for periodic refresh
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        Update-InstanceList -DataGridView $dgvInstances
        Update-LogDisplay -TextBox $txtLog
    })
    $timer.Start()

    # Form closing cleanup
    $form.Add_FormClosing({
        $timer.Stop()

        foreach ($connId in $Global:Connections.Keys) {
            try {
                Stop-Connection -ConnectionId $connId -Force
            } catch {
                # ignore errors
            }
        }
    })

    $form.Add_FormClosed({
        param($sender, $eventArgs)

        if ($script:CurrentMainForm -eq $sender) {
            $script:CurrentMainForm = $null
        }
    })

    # Initial load
    Update-InstanceList -DataGridView $dgvInstances

    # Show form
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()

    if ($script:CurrentMainForm -eq $form) {
        $script:CurrentMainForm = $null
    }
}

function Update-InstanceList {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView
    )

    if (-not $DataGridView) {
        return
    }

    $selectedId = $null
    if ($DataGridView.SelectedRows.Count -gt 0 -and $DataGridView.Columns.Contains("Id")) {
        $selectedId = $DataGridView.SelectedRows[0].Cells["Id"].Value
    }

    $firstDisplayedIndex = $null
    try {
        if ($DataGridView.RowCount -gt 0 -and $DataGridView.FirstDisplayedScrollingRowIndex -ge 0) {
            $firstDisplayedIndex = $DataGridView.FirstDisplayedScrollingRowIndex
        }
    } catch {
        $firstDisplayedIndex = $null
    }

    $DataGridView.Rows.Clear()

    if (-not $Global:Connections) {
        return
    }

    foreach ($conn in $Global:Connections.Values | Sort-Object DisplayName) {
        $endpoint = ""
        if ($conn.Mode -eq "Client" -or $conn.Mode -eq "Sender") {
            $endpoint = "$($conn.RemoteIP):$($conn.RemotePort)"
        } else {
            $endpoint = "$($conn.LocalIP):$($conn.LocalPort)"
        }

        $rowIndex = $DataGridView.Rows.Add(
            $conn.DisplayName,
            "$($conn.Protocol) $($conn.Mode)",
            $endpoint,
            $conn.Status,
            $null,
            $null,
            $null,
            $null,
            $null,
            $conn.Id
        )

        $row = $DataGridView.Rows[$rowIndex]

        try {
            $suppressScenarioEvent = $true

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
            if ($conn.Variables.ContainsKey('AutoResponseProfile')) {
                $currentProfile = $conn.Variables['AutoResponseProfile']
            }
            if ($conn.Variables.ContainsKey('AutoResponseProfilePath')) {
                $currentPath = $conn.Variables['AutoResponseProfilePath']
            }

            $instancePath = $null
            if ($conn.Variables.ContainsKey('InstancePath')) {
                $instancePath = $conn.Variables['InstancePath']
            }

            $profiles = @()
            if ($instancePath) {
                try {
                    $profiles = Get-InstanceAutoResponseProfiles -InstancePath $instancePath
                } catch {
                    $profiles = @()
                }
            }

            foreach ($profile in $profiles) {
                if ([string]::IsNullOrWhiteSpace($profile.Name)) {
                    continue
                }

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

            if ($instancePath) {
                try {
                    $scenarioFiles = Get-InstanceScenarios -InstancePath $instancePath
                } catch {
                    $scenarioFiles = @()
                }

                if ($scenarioFiles -and $scenarioFiles.Count -gt 0) {
                    $scenarioRoot = Join-Path $instancePath "scenarios"
                    foreach ($scenario in $scenarioFiles) {
                        $scenarioKey = "scenario::$scenario"
                        $scenarioPath = Join-Path $scenarioRoot $scenario
                        $entry = [PSCustomObject]@{
                            Display = "‚ñ∂ $scenario"
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

            $scenarioCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $scenarioCell.DisplayMember = "Display"
            $scenarioCell.ValueMember = "Key"
            $scenarioCell.DataSource = $items
            $scenarioCell.Value = $currentKey
            $scenarioCell.Tag = @{
                Mapping    = $mapping
                ProfileKey = $currentKey
            }
            $row.Cells["Scenario"] = $scenarioCell

            # OnReceivedóÒÇÃê›íË
            $onReceivedItems = New-Object System.Collections.ArrayList
            $onReceivedMapping = @{}

            $onReceivedNone = [PSCustomObject]@{
                Display = "(None)"
                Key     = ""
                Type    = "Profile"
                Name    = $null
                Path    = $null
            }
            [void]$onReceivedItems.Add($onReceivedNone)
            $onReceivedMapping[$onReceivedNone.Key] = $onReceivedNone

            $currentOnReceivedProfile = ""
            $currentOnReceivedPath = $null
            if ($conn.Variables.ContainsKey('OnReceivedProfile')) {
                $currentOnReceivedProfile = $conn.Variables['OnReceivedProfile']
            }
            if ($conn.Variables.ContainsKey('OnReceivedProfilePath')) {
                $currentOnReceivedPath = $conn.Variables['OnReceivedProfilePath']
            }

            $onReceivedProfiles = @()
            if ($instancePath) {
                try {
                    $onReceivedProfiles = Get-InstanceOnReceivedProfiles -InstancePath $instancePath
                } catch {
                    $onReceivedProfiles = @()
                }
            }

            foreach ($profile in $onReceivedProfiles) {
                if ([string]::IsNullOrWhiteSpace($profile.Name)) {
                    continue
                }

                $key = "onreceived::$($profile.Name)"
                $entry = [PSCustomObject]@{
                    Display = $profile.DisplayName
                    Key     = $key
                    Type    = "Profile"
                    Name    = $profile.Name
                    Path    = $profile.FilePath
                }

                [void]$onReceivedItems.Add($entry)
                $onReceivedMapping[$key] = $entry
            }

            $currentOnReceivedKey = ""
            if ($currentOnReceivedProfile) {
                $currentOnReceivedKey = "onreceived::$currentOnReceivedProfile"
                if (-not $onReceivedMapping.ContainsKey($currentOnReceivedKey)) {
                    $displayName = if ($currentOnReceivedPath) { "$currentOnReceivedProfile (missing)" } else { $currentOnReceivedProfile }
                    $entry = [PSCustomObject]@{
                        Display = $displayName
                        Key     = $currentOnReceivedKey
                        Type    = "Profile"
                        Name    = $currentOnReceivedProfile
                        Path    = $currentOnReceivedPath
                    }
                    [void]$onReceivedItems.Add($entry)
                    $onReceivedMapping[$currentOnReceivedKey] = $entry
                }
            }

            $onReceivedCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $onReceivedCell.DisplayMember = "Display"
            $onReceivedCell.ValueMember = "Key"
            $onReceivedCell.DataSource = $onReceivedItems
            $onReceivedCell.Value = $currentOnReceivedKey
            $onReceivedCell.Tag = @{
                Mapping              = $onReceivedMapping
                OnReceivedProfileKey = $currentOnReceivedKey
            }
            $row.Cells["OnReceived"] = $onReceivedCell

            # Periodic Send profiles
            $periodicSendProfiles = @()
            if ($instancePath) {
                try {
                    $periodicSendProfiles = Get-InstancePeriodicSendProfiles -InstancePath $instancePath
                } catch {
                    $periodicSendProfiles = @()
                }
            }

            $periodicSendItems = New-Object System.Collections.ArrayList
            $periodicSendMapping = @{}
            
            $periodicSendPlaceholder = [PSCustomObject]@{
                Display = "(None)"
                Key     = ""
                Type    = "None"
                Name    = $null
                Path    = $null
            }
            [void]$periodicSendItems.Add($periodicSendPlaceholder)
            $periodicSendMapping[$periodicSendPlaceholder.Key] = $periodicSendPlaceholder

            foreach ($profile in $periodicSendProfiles) {
                $key = "periodic::$($profile.ProfileName)"
                $entry = [PSCustomObject]@{
                    Display = $profile.ProfileName
                    Key     = $key
                    Type    = "Profile"
                    Name    = $profile.ProfileName
                    Path    = $profile.FilePath
                }

                [void]$periodicSendItems.Add($entry)
                $periodicSendMapping[$key] = $entry
            }

            $periodicSendCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $periodicSendCell.DisplayMember = "Display"
            $periodicSendCell.ValueMember = "Key"
            $periodicSendCell.DataSource = $periodicSendItems
            $periodicSendCell.Value = ""
            $periodicSendCell.Tag = @{
                Mapping              = $periodicSendMapping
                PeriodicSendProfileKey = ""
            }
            $row.Cells["PeriodicSend"] = $periodicSendCell

            $dataBankEntries = @()
            $dataBankPath = $null
            if ($instancePath) {
                $dataBankPath = Join-Path $instancePath "templates\databank.csv"
                try {
                    $dataBankEntries = Get-InstanceDataBank -InstancePath $instancePath
                } catch {
                    $dataBankEntries = @()
                }
            }

            $quickDataCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $quickDataCell.DisplayMember = "Display"
            $quickDataCell.ValueMember = "Key"
            $quickDataCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

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

            $quickDataCell.DataSource = $dataSource
            $quickDataCell.Value = ""
            $quickDataCell.Tag = @{
                DataBankCount = $dataBankEntries.Count
                DataBankPath  = if ($dataBankPath -and (Test-Path -LiteralPath $dataBankPath)) { $dataBankPath } else { $null }
            }
            $row.Cells["QuickData"] = $quickDataCell

            $quickActionCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $quickActionCell.DisplayMember = "Display"
            $quickActionCell.ValueMember = "Key"
            $quickActionCell.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

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

            $quickActionCell.DataSource = $actionSource
            $quickActionCell.Value = ""
            $quickActionCell.Tag = @{
                Mapping = $actionMapping
            }
            $row.Cells["QuickAction"] = $quickActionCell
        } catch {
            $row.Cells["Scenario"].Value = ""
        } finally {
            $suppressScenarioEvent = $false
        }

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
            default {
                $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
            }
        }
    }

    if ($selectedId) {
        foreach ($row in $DataGridView.Rows) {
            if ($row.Cells["Id"].Value -eq $selectedId) {
                $row.Selected = $true
                if ($row.Cells.Count -gt 0) {
                    $DataGridView.CurrentCell = $row.Cells[0]
                }
                break
            }
        }
    }

    if ($firstDisplayedIndex -ne $null -and $DataGridView.RowCount -gt 0) {
        $targetIndex = [Math]::Min([Math]::Max(0, $firstDisplayedIndex), $DataGridView.RowCount - 1)
        try {
            $DataGridView.FirstDisplayedScrollingRowIndex = $targetIndex
        } catch {
            # ignore scroll errors
        }
    }
}

function Update-LogDisplay {
    param(
        [System.Windows.Forms.TextBox]$TextBox
    )

    if (-not $TextBox) {
        return
    }

    $logLines = @()

    foreach ($conn in $Global:Connections.Values) {
        $snapshot = @()

        try {
            if ($conn.RecvBuffer -and $conn.RecvBuffer.Count -gt 0) {
                $syncRoot = $conn.RecvBuffer.SyncRoot
                [System.Threading.Monitor]::Enter($syncRoot)
                try {
                    $snapshot = $conn.RecvBuffer.ToArray()
                } finally {
                    [System.Threading.Monitor]::Exit($syncRoot)
                }
            }
        } catch {
            continue
        }

        if (-not $snapshot -or $snapshot.Length -eq 0) {
            continue
        }

        $count = $snapshot.Length
        $startIndex = [Math]::Max(0, $count - 10)
        for ($i = $startIndex; $i -lt $count; $i++) {
            $recv = $snapshot[$i]
            if (-not $recv) { continue }

            $summary = Get-MessageSummary -Data $recv.Data -MaxLength 40
            $timeStr = $recv.Timestamp.ToString("HH:mm:ss")
            $logLines += "[$timeStr] $($conn.DisplayName) ‚á? $summary ($($recv.Length) bytes)"
        }
    }

    $logLines = $logLines | Select-Object -Last 100

    $TextBox.Text = $logLines -join "`r`n"
    $TextBox.SelectionStart = $TextBox.Text.Length
    $TextBox.ScrollToCaret()
}

# Export-ModuleMember -Function 'Show-MainForm'
