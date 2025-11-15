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

    # Quick sender controls
    $grpQuick = New-Object System.Windows.Forms.GroupBox
    $grpQuick.Text = "Quick Sender"
    $grpQuick.Location = New-Object System.Drawing.Point(10, 290)
    $grpQuick.Size = New-Object System.Drawing.Size(1165, 150)

    $lblCategory = New-Object System.Windows.Forms.Label
    $lblCategory.Location = New-Object System.Drawing.Point(10, 25)
    $lblCategory.Size = New-Object System.Drawing.Size(70, 20)
    $lblCategory.Text = "Category"
    $grpQuick.Controls.Add($lblCategory)

    $cmbCategory = New-Object System.Windows.Forms.ComboBox
    $cmbCategory.Location = New-Object System.Drawing.Point(80, 22)
    $cmbCategory.Size = New-Object System.Drawing.Size(180, 23)
    $cmbCategory.DropDownStyle = "DropDownList"
    $grpQuick.Controls.Add($cmbCategory)

    $btnReloadData = New-Object System.Windows.Forms.Button
    $btnReloadData.Location = New-Object System.Drawing.Point(270, 20)
    $btnReloadData.Size = New-Object System.Drawing.Size(80, 25)
    $btnReloadData.Text = "Reload"
    $grpQuick.Controls.Add($btnReloadData)

    $lstDataItems = New-Object System.Windows.Forms.ListBox
    $lstDataItems.Location = New-Object System.Drawing.Point(10, 50)
    $lstDataItems.Size = New-Object System.Drawing.Size(250, 60)
    $lstDataItems.DisplayMember = "DataID"
    $grpQuick.Controls.Add($lstDataItems)

    $lblPreview = New-Object System.Windows.Forms.Label
    $lblPreview.Location = New-Object System.Drawing.Point(270, 50)
    $lblPreview.Size = New-Object System.Drawing.Size(150, 20)
    $lblPreview.Text = "Preview"
    $grpQuick.Controls.Add($lblPreview)

    $txtPreview = New-Object System.Windows.Forms.TextBox
    $txtPreview.Location = New-Object System.Drawing.Point(270, 70)
    $txtPreview.Size = New-Object System.Drawing.Size(285, 45)
    $txtPreview.Multiline = $true
    $txtPreview.ReadOnly = $true
    $grpQuick.Controls.Add($txtPreview)

    $lblGroup = New-Object System.Windows.Forms.Label
    $lblGroup.Location = New-Object System.Drawing.Point(10, 115)
    $lblGroup.Size = New-Object System.Drawing.Size(45, 20)
    $lblGroup.Text = "Group"
    $grpQuick.Controls.Add($lblGroup)

    $cmbGroup = New-Object System.Windows.Forms.ComboBox
    $cmbGroup.Location = New-Object System.Drawing.Point(60, 112)
    $cmbGroup.Size = New-Object System.Drawing.Size(200, 23)
    $cmbGroup.DropDownStyle = "DropDownList"
    $grpQuick.Controls.Add($cmbGroup)

    $btnSendSingle = New-Object System.Windows.Forms.Button
    $btnSendSingle.Location = New-Object System.Drawing.Point(270, 120)
    $btnSendSingle.Size = New-Object System.Drawing.Size(130, 25)
    $btnSendSingle.Text = "Send to Selected"
    $grpQuick.Controls.Add($btnSendSingle)

    $btnSendGroup = New-Object System.Windows.Forms.Button
    $btnSendGroup.Location = New-Object System.Drawing.Point(410, 120)
    $btnSendGroup.Size = New-Object System.Drawing.Size(145, 25)
    $btnSendGroup.Text = "Send to Group"
    $grpQuick.Controls.Add($btnSendGroup)

    $form.Controls.Add($grpQuick)

    # Log area
    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Location = New-Object System.Drawing.Point(10, 450)
    $lblLog.Size = New-Object System.Drawing.Size(200, 20)
    $lblLog.Text = "Connection Log:"
    $form.Controls.Add($lblLog)

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Location = New-Object System.Drawing.Point(10, 475)
    $txtLog.Size = New-Object System.Drawing.Size(1165, 170)
    $txtLog.Multiline = $true
    $txtLog.ScrollBars = "Vertical"
    $txtLog.ReadOnly = $true
    $txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
    $form.Controls.Add($txtLog)

    # State holders
    $currentDataBank = @()
    $suppressCategoryEvent = $false
    $suppressScenarioEvent = $false
    $lastSelectedConnectionId = $null

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

    $refreshQuickSender = {
        param($connection)

        $suppressCategoryEvent = $true
        $cmbCategory.Items.Clear()
        $lstDataItems.Items.Clear()
        $txtPreview.Clear()
        $suppressCategoryEvent = $false

        $currentDataBank = @()

        if (-not $connection) {
            return
        }

        if (-not $connection.Variables.ContainsKey('InstancePath')) {
            return
        }

        $instancePath = $connection.Variables['InstancePath']
        if (-not $instancePath) {
            return
        }

        try {
            $currentDataBank = Get-InstanceDataBank -InstancePath $instancePath
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load data bank: $_", "Error") | Out-Null
            return
        }

        if ($currentDataBank.Count -eq 0) {
            return
        }

        $categories = Get-DataBankCategories -DataBank $currentDataBank

        $suppressCategoryEvent = $true
        foreach ($category in $categories) {
            [void]$cmbCategory.Items.Add($category)
        }

        if ($cmbCategory.Items.Count -gt 0) {
            $cmbCategory.SelectedIndex = 0
        }

        $suppressCategoryEvent = $false
    }

    $refreshGroupList = {
        $selectedGroup = $cmbGroup.SelectedItem
        $cmbGroup.Items.Clear()

        try {
            $groups = Get-GroupNames
            foreach ($group in $groups) {
                [void]$cmbGroup.Items.Add($group)
            }
        } catch {
            # ignore failures
        }

        if ($selectedGroup -and $cmbGroup.Items.Contains($selectedGroup)) {
            $cmbGroup.SelectedItem = $selectedGroup
        } elseif ($cmbGroup.Items.Count -gt 0) {
            $cmbGroup.SelectedIndex = 0
        }
    }

    $updateDetails = {
        param([bool]$ForceRefresh = $false)

        $connection = & $getSelectedConnection
        $connectionId = $null

        if ($connection) {
            $connectionId = $connection.Id
        }

        if (-not $ForceRefresh -and $connectionId -eq $lastSelectedConnectionId) {
            return
        }

        $lastSelectedConnectionId = $connectionId

        & $refreshQuickSender $connection
    }

    # Events
    $btnRefresh.Add_Click({
        Update-InstanceList -DataGridView $dgvInstances
        & $updateDetails $true
        & $refreshGroupList
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
            & $updateDetails $true
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
            & $updateDetails $true
        }
    })

    $dgvInstances.Add_SelectionChanged({
        & $updateDetails
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

    $cmbCategory.Add_SelectedIndexChanged({
        if ($suppressCategoryEvent) { return }

        $lstDataItems.Items.Clear()
        $txtPreview.Clear()

        if (-not $cmbCategory.SelectedItem) {
            return
        }

        $selectedCategory = $cmbCategory.SelectedItem
        $items = Get-DataBankByCategory -DataBank $currentDataBank -Category $selectedCategory
        foreach ($item in $items) {
            [void]$lstDataItems.Items.Add($item)
        }

        if ($lstDataItems.Items.Count -gt 0) {
            $lstDataItems.SelectedIndex = 0
        }
    })

    $lstDataItems.Add_SelectedIndexChanged({
        $item = $lstDataItems.SelectedItem
        if ($item) {
            $previewText = "Type: {0}`r`nDescription: {1}`r`nContent: {2}" -f $item.Type, $item.Description, $item.Content
            $txtPreview.Text = $previewText
        } else {
            $txtPreview.Clear()
        }
    })

    $btnReloadData.Add_Click({
        $connection = & $getSelectedConnection
        & $refreshQuickSender $connection
    })

    $btnSendSingle.Add_Click({
        $connection = & $getSelectedConnection
        if (-not $connection) {
            [System.Windows.Forms.MessageBox]::Show("Please select a connection first.", "Warning") | Out-Null
            return
        }

        $item = $lstDataItems.SelectedItem
        if (-not $item) {
            [System.Windows.Forms.MessageBox]::Show("Please choose a data item to send.", "Warning") | Out-Null
            return
        }

        try {
            Send-QuickData -ConnectionId $connection.Id -DataID $item.DataID -DataBank $currentDataBank
            [System.Windows.Forms.MessageBox]::Show("Sent data item '$($item.DataID)' to $($connection.DisplayName).", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to send data: $_", "Error") | Out-Null
        }
    })

    $btnSendGroup.Add_Click({
        $item = $lstDataItems.SelectedItem
        if (-not $item) {
            [System.Windows.Forms.MessageBox]::Show("Please choose a data item to send.", "Warning") | Out-Null
            return
        }

        $groupName = $cmbGroup.SelectedItem
        if (-not $groupName) {
            [System.Windows.Forms.MessageBox]::Show("Please choose a group to send to.", "Warning") | Out-Null
            return
        }

        try {
            Send-QuickDataToGroup -GroupName $groupName -DataID $item.DataID -DataBank $currentDataBank
            [System.Windows.Forms.MessageBox]::Show("Sent data item '$($item.DataID)' to group '$groupName'.", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to send data to group: $_", "Error") | Out-Null
        }
    })

    # Timer for periodic refresh
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        Update-InstanceList -DataGridView $dgvInstances
        Update-LogDisplay -TextBox $txtLog
        & $refreshGroupList
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

    # Initial load
    Update-InstanceList -DataGridView $dgvInstances
    & $updateDetails $true
    & $refreshGroupList

    # Show form
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
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
            $conn.Id
        )

        $row = $DataGridView.Rows[$rowIndex]

        try {
            $suppressScenarioEvent = $true

            $items = New-Object System.Collections.ArrayList
            $mapping = @{}

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
                            Display = "▶ $scenario"
                            Key     = $scenarioKey
                            Type    = "Scenario"
                            Name    = $scenario
                            Path    = $scenarioPath
                        }
                        [void]$items.Add($entry)
                        $mapping[$scenarioKey] = $entry
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
            $logLines += "[$timeStr] $($conn.DisplayName) ⇐ $summary ($($recv.Length) bytes)"
        }
    }

    $logLines = $logLines | Select-Object -Last 100

    $TextBox.Text = $logLines -join "`r`n"
    $TextBox.SelectionStart = $TextBox.Text.Length
    $TextBox.ScrollToCaret()
}

# Export-ModuleMember -Function 'Show-MainForm'
