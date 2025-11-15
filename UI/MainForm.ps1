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

    # Scenario controls
    $grpScenario = New-Object System.Windows.Forms.GroupBox
    $grpScenario.Text = "Scenario Control"
    $grpScenario.Location = New-Object System.Drawing.Point(10, 290)
    $grpScenario.Size = New-Object System.Drawing.Size(570, 150)

    $lblScenarioList = New-Object System.Windows.Forms.Label
    $lblScenarioList.Location = New-Object System.Drawing.Point(10, 25)
    $lblScenarioList.Size = New-Object System.Drawing.Size(150, 20)
    $lblScenarioList.Text = "Available Scenarios"
    $grpScenario.Controls.Add($lblScenarioList)

    $lstScenarios = New-Object System.Windows.Forms.ListBox
    $lstScenarios.Location = New-Object System.Drawing.Point(10, 50)
    $lstScenarios.Size = New-Object System.Drawing.Size(250, 60)
    $grpScenario.Controls.Add($lstScenarios)

    $txtScenarioPath = New-Object System.Windows.Forms.TextBox
    $txtScenarioPath.Location = New-Object System.Drawing.Point(270, 50)
    $txtScenarioPath.Size = New-Object System.Drawing.Size(285, 23)
    $txtScenarioPath.ReadOnly = $true
    $grpScenario.Controls.Add($txtScenarioPath)

    $btnScenarioRefresh = New-Object System.Windows.Forms.Button
    $btnScenarioRefresh.Location = New-Object System.Drawing.Point(10, 115)
    $btnScenarioRefresh.Size = New-Object System.Drawing.Size(80, 25)
    $btnScenarioRefresh.Text = "Refresh"
    $grpScenario.Controls.Add($btnScenarioRefresh)

    $btnScenarioBrowse = New-Object System.Windows.Forms.Button
    $btnScenarioBrowse.Location = New-Object System.Drawing.Point(100, 115)
    $btnScenarioBrowse.Size = New-Object System.Drawing.Size(80, 25)
    $btnScenarioBrowse.Text = "Browse..."
    $grpScenario.Controls.Add($btnScenarioBrowse)

    $btnScenarioRun = New-Object System.Windows.Forms.Button
    $btnScenarioRun.Location = New-Object System.Drawing.Point(270, 115)
    $btnScenarioRun.Size = New-Object System.Drawing.Size(140, 25)
    $btnScenarioRun.Text = "Run Scenario"
    $grpScenario.Controls.Add($btnScenarioRun)

    $btnScenarioOpenFolder = New-Object System.Windows.Forms.Button
    $btnScenarioOpenFolder.Location = New-Object System.Drawing.Point(420, 115)
    $btnScenarioOpenFolder.Size = New-Object System.Drawing.Size(135, 25)
    $btnScenarioOpenFolder.Text = "Open Folder"
    $grpScenario.Controls.Add($btnScenarioOpenFolder)

    $form.Controls.Add($grpScenario)

    # Quick sender controls
    $grpQuick = New-Object System.Windows.Forms.GroupBox
    $grpQuick.Text = "Quick Sender"
    $grpQuick.Location = New-Object System.Drawing.Point(605, 290)
    $grpQuick.Size = New-Object System.Drawing.Size(570, 150)

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

    $refreshScenarioList = {
        param($connection)

        $lstScenarios.Items.Clear()
        $txtScenarioPath.Clear()

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
            $scenarios = Get-InstanceScenarios -InstancePath $instancePath
            foreach ($scenario in $scenarios) {
                [void]$lstScenarios.Items.Add($scenario)
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load scenarios: $_", "Error") | Out-Null
        }
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
        $connection = & $getSelectedConnection
        & $refreshScenarioList $connection
        & $refreshQuickSender $connection
    }

    # Events
    $btnRefresh.Add_Click({
        Update-InstanceList -DataGridView $dgvInstances
        & $updateDetails
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
            & $updateDetails
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
            & $updateDetails
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
        $selectedKey = $cell.Value
        $profilePath = $null
        $mapping = $cell.Tag
        if ($mapping -and $selectedKey -and $mapping.ContainsKey($selectedKey)) {
            $profilePath = $mapping[$selectedKey]
        }

        try {
            Set-ConnectionAutoResponseProfile -ConnectionId $connId -ProfileName $selectedKey -ProfilePath $profilePath | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to apply auto-response profile: $_", "Error") | Out-Null
        }
    })

    $lstScenarios.Add_SelectedIndexChanged({
        if ($lstScenarios.SelectedItem) {
            $connection = & $getSelectedConnection
            if ($connection -and $connection.Variables.ContainsKey('InstancePath')) {
                $scenarioRoot = Join-Path $connection.Variables['InstancePath'] "scenarios"
                $fullPath = Join-Path $scenarioRoot $lstScenarios.SelectedItem
                $txtScenarioPath.Text = $fullPath
            }
        } else {
            $txtScenarioPath.Clear()
        }
    })

    $lstScenarios.Add_DoubleClick({
        $btnScenarioRun.PerformClick()
    })

    $btnScenarioRefresh.Add_Click({
        $connection = & $getSelectedConnection
        & $refreshScenarioList $connection
    })

    $btnScenarioBrowse.Add_Click({
        $connection = & $getSelectedConnection
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
        if ($connection -and $connection.Variables.ContainsKey('InstancePath')) {
            $scenarioDir = Join-Path $connection.Variables['InstancePath'] "scenarios"
            if (Test-Path $scenarioDir) {
                $dialog.InitialDirectory = $scenarioDir
            }
        }

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtScenarioPath.Text = $dialog.FileName
        }
    })

    $btnScenarioOpenFolder.Add_Click({
        $connection = & $getSelectedConnection
        if ($connection -and $connection.Variables.ContainsKey('InstancePath')) {
            $scenarioDir = Join-Path $connection.Variables['InstancePath'] "scenarios"
            if (Test-Path $scenarioDir) {
                Start-Process "explorer.exe" $scenarioDir
            } else {
                [System.Windows.Forms.MessageBox]::Show("Scenario folder not found:`n$scenarioDir", "Information") | Out-Null
            }
        }
    })

    $btnScenarioRun.Add_Click({
        $connection = & $getSelectedConnection
        if (-not $connection) {
            [System.Windows.Forms.MessageBox]::Show("Please select a connection first.", "Warning") | Out-Null
            return
        }

        $scenarioPath = $txtScenarioPath.Text
        if (-not $scenarioPath -or -not (Test-Path $scenarioPath)) {
            [System.Windows.Forms.MessageBox]::Show("Scenario file not found. Please choose a scenario.", "Warning") | Out-Null
            return
        }

        try {
            Start-Scenario -ConnectionId $connection.Id -ScenarioPath $scenarioPath
            $scenarioName = [System.IO.Path]::GetFileName($scenarioPath)
            [System.Windows.Forms.MessageBox]::Show("Scenario started: $scenarioName", "Success") | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to start scenario: $_", "Error") | Out-Null
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
    & $updateDetails
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
            [void]$items.Add([PSCustomObject]@{ Display = "(None)"; Key = ""; Path = $null })

            $mapping = @{}
            $currentProfile = ""
            $currentPath = $null
            if ($conn.Variables.ContainsKey('AutoResponseProfile')) {
                $currentProfile = $conn.Variables['AutoResponseProfile']
            }
            if ($conn.Variables.ContainsKey('AutoResponseProfilePath')) {
                $currentPath = $conn.Variables['AutoResponseProfilePath']
            }

            $profiles = @()
            if ($conn.Variables.ContainsKey('InstancePath')) {
                $instancePath = $conn.Variables['InstancePath']
                if ($instancePath) {
                    try {
                        $profiles = Get-InstanceAutoResponseProfiles -InstancePath $instancePath
                    } catch {
                        $profiles = @()
                    }
                }
            }

            foreach ($profile in $profiles) {
                [void]$items.Add([PSCustomObject]@{ Display = $profile.DisplayName; Key = $profile.Name; Path = $profile.FilePath })
                if ($profile.Name) {
                    $mapping[$profile.Name] = $profile.FilePath
                }
            }

            if ($currentProfile -and -not $mapping.ContainsKey($currentProfile)) {
                $displayName = if ($currentPath) { "$currentProfile (missing)" } else { $currentProfile }
                [void]$items.Add([PSCustomObject]@{ Display = $displayName; Key = $currentProfile; Path = $currentPath })
                if ($currentPath) {
                    $mapping[$currentProfile] = $currentPath
                }
            }

            $scenarioCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
            $scenarioCell.DisplayMember = "Display"
            $scenarioCell.ValueMember = "Key"
            $scenarioCell.DataSource = $items
            $scenarioCell.Value = if ($currentProfile) { $currentProfile } else { "" }
            $scenarioCell.Tag = $mapping
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
        $recentRecv = $conn.RecvBuffer | Select-Object -Last 10
        foreach ($recv in $recentRecv) {
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
