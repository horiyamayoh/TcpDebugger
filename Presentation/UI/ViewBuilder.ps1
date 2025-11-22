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
        [string]$Title = "TCP Test Controller v1.0",
        [int]$Width = 1200,
        [int]$Height = 700
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.StartPosition = "CenterScreen"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

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
    $dgv.AllowUserToAddRows = $false
    $dgv.AllowUserToDeleteRows = $false
    $dgv.AllowUserToResizeRows = $false
    $dgv.RowHeadersVisible = $false
    $dgv.ReadOnly = $false
    $dgv.SelectionMode = "FullRowSelect"
    $dgv.MultiSelect = $false
    $dgv.AutoSizeColumnsMode = "Fill"
    $dgv.AutoGenerateColumns = $false
    $dgv.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter

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

    # Endpoint column
    $colEndpoint = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colEndpoint.HeaderText = "Endpoint"
    $colEndpoint.Name = "Endpoint"
    $colEndpoint.ReadOnly = $true
    $colEndpoint.FillWeight = 160
    [void]$DataGridView.Columns.Add($colEndpoint)

    # Status column
    $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStatus.HeaderText = "Status"
    $colStatus.Name = "Status"
    $colStatus.ReadOnly = $true
    $colStatus.FillWeight = 100
    [void]$DataGridView.Columns.Add($colStatus)

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

    # Auto Response column (ComboBox)
    $colAutoResponse = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colAutoResponse.HeaderText = "Auto Response"
    $colAutoResponse.Name = "Scenario"
    $colAutoResponse.DisplayMember = "Display"
    $colAutoResponse.ValueMember = "Key"
    $colAutoResponse.ValueType = [string]
    $colAutoResponse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colAutoResponse.FillWeight = 140
    [void]$DataGridView.Columns.Add($colAutoResponse)

    # OnReceived column (ComboBox)
    $colOnReceived = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnReceived.HeaderText = "On Received"
    $colOnReceived.Name = "OnReceived"
    $colOnReceived.DisplayMember = "Display"
    $colOnReceived.ValueMember = "Key"
    $colOnReceived.ValueType = [string]
    $colOnReceived.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnReceived.FillWeight = 140
    [void]$DataGridView.Columns.Add($colOnReceived)

    # Periodic Send column (ComboBox)
    $colPeriodicSend = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colPeriodicSend.HeaderText = "Periodic Send"
    $colPeriodicSend.Name = "PeriodicSend"
    $colPeriodicSend.DisplayMember = "Display"
    $colPeriodicSend.ValueMember = "Key"
    $colPeriodicSend.ValueType = [string]
    $colPeriodicSend.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colPeriodicSend.FillWeight = 140
    [void]$DataGridView.Columns.Add($colPeriodicSend)

    # Quick Data column (ComboBox)
    $colQuickData = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colQuickData.HeaderText = "Quick Data"
    $colQuickData.Name = "QuickData"
    $colQuickData.DisplayMember = "Display"
    $colQuickData.ValueMember = "Key"
    $colQuickData.ValueType = [string]
    $colQuickData.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colQuickData.FillWeight = 170
    [void]$DataGridView.Columns.Add($colQuickData)

    # Quick Send button column
    $colQuickSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colQuickSend.HeaderText = "Send"
    $colQuickSend.Name = "QuickSend"
    $colQuickSend.Text = "Send"
    $colQuickSend.UseColumnTextForButtonValue = $true
    $colQuickSend.FillWeight = 70
    [void]$DataGridView.Columns.Add($colQuickSend)

    # Quick Action column (ComboBox)
    $colQuickAction = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colQuickAction.HeaderText = "Quick Action"
    $colQuickAction.Name = "QuickAction"
    $colQuickAction.DisplayMember = "Display"
    $colQuickAction.ValueMember = "Key"
    $colQuickAction.ValueType = [string]
    $colQuickAction.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colQuickAction.FillWeight = 170
    [void]$DataGridView.Columns.Add($colQuickAction)

    # Action Send button column
    $colActionSend = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colActionSend.HeaderText = "Run"
    $colActionSend.Name = "ActionSend"
    $colActionSend.Text = "Run"
    $colActionSend.UseColumnTextForButtonValue = $true
    $colActionSend.FillWeight = 70
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
        [int]$Height = 30
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.Text = $Text

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
        [int]$Height = 20
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.Text = $Text

    return $label
}

function New-LogTextBox {
    <#
    .SYNOPSIS
    Creates a multi-line log text box.
    #>
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point($X, $Y)
    $textBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $textBox.Multiline = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.ReadOnly = $true
    $textBox.Font = New-Object System.Drawing.Font("Consolas", 9)

    return $textBox
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
    Configures the Scenario (Auto Response) column cell for a connection row.
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
    if ($Connection.Variables.ContainsKey('AutoResponseProfile')) {
        $currentProfile = $Connection.Variables['AutoResponseProfile']
    }
    if ($Connection.Variables.ContainsKey('AutoResponseProfilePath')) {
        $currentPath = $Connection.Variables['AutoResponseProfilePath']
    }

    # Add profiles
    $profiles = @()
    if ($InstancePath) {
        try {
            $profiles = Get-InstanceAutoResponseProfiles -InstancePath $InstancePath
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

function Configure-OnReceivedColumn {
    <#
    .SYNOPSIS
    Configures the OnReceived column cell for a connection row.
    #>
    param(
        $Row,
        $Connection,
        [string]$InstancePath
    )

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
    if ($Connection.Variables.ContainsKey('OnReceivedProfile')) {
        $currentOnReceivedProfile = $Connection.Variables['OnReceivedProfile']
    }
    if ($Connection.Variables.ContainsKey('OnReceivedProfilePath')) {
        $currentOnReceivedPath = $Connection.Variables['OnReceivedProfilePath']
    }

    $onReceivedProfiles = @()
    if ($InstancePath) {
        try {
            $onReceivedProfiles = Get-InstanceOnReceivedProfiles -InstancePath $InstancePath
        } catch {
            $onReceivedProfiles = @()
        }
    }

    foreach ($prof in $onReceivedProfiles) {
        if ([string]::IsNullOrWhiteSpace($prof.Name)) { continue }

        $key = "onreceived::$($prof.Name)"
        $entry = [PSCustomObject]@{
            Display = $prof.DisplayName
            Key     = $key
            Type    = "Profile"
            Name    = $prof.Name
            Path    = $prof.FilePath
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
    foreach ($item in $onReceivedItems) {
        [void]$onReceivedCell.Items.Add($item)
    }
    $onReceivedCell.Value = $currentOnReceivedKey
    $onReceivedCell.Tag = @{
        Mapping              = $onReceivedMapping
        OnReceivedProfileKey = $currentOnReceivedKey
    }
    $Row.Cells["OnReceived"] = $onReceivedCell
}

function Configure-PeriodicSendColumn {
    <#
    .SYNOPSIS
    Configures the Periodic Send column cell for a connection row.
    #>
    param(
        $Row,
        $Connection,
        [string]$InstancePath
    )

    $currentPeriodicSendProfile = ""
    $currentPeriodicSendPath = $null
    if ($Connection.Variables.ContainsKey('PeriodicSendProfile')) {
        $currentPeriodicSendProfile = $Connection.Variables['PeriodicSendProfile']
    }
    if ($Connection.Variables.ContainsKey('PeriodicSendProfilePath')) {
        $currentPeriodicSendPath = $Connection.Variables['PeriodicSendProfilePath']
    }

    $periodicSendProfiles = @()
    if ($InstancePath) {
        try {
            $periodicSendProfiles = Get-InstancePeriodicSendProfiles -InstancePath $InstancePath
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

    foreach ($prof in $periodicSendProfiles) {
        $key = "periodicsend::$($prof.ProfileName)"
        $entry = [PSCustomObject]@{
            Display = $prof.ProfileName
            Key     = $key
            Type    = "Profile"
            Name    = $prof.ProfileName
            Path    = $prof.FilePath
        }
        [void]$periodicSendItems.Add($entry)
        $periodicSendMapping[$key] = $entry
    }

    $currentPeriodicSendKey = ""
    if ($currentPeriodicSendProfile) {
        $currentPeriodicSendKey = "periodicsend::$currentPeriodicSendProfile"
        if (-not $periodicSendMapping.ContainsKey($currentPeriodicSendKey)) {
            $displayName = if ($currentPeriodicSendPath) { "$currentPeriodicSendProfile (missing)" } else { $currentPeriodicSendProfile }
            $entry = [PSCustomObject]@{
                Display = $displayName
                Key     = $currentPeriodicSendKey
                Type    = "Profile"
                Name    = $currentPeriodicSendProfile
                Path    = $currentPeriodicSendPath
            }
            [void]$periodicSendItems.Add($entry)
            $periodicSendMapping[$currentPeriodicSendKey] = $entry
        }
    }

    $periodicSendCell = New-Object System.Windows.Forms.DataGridViewComboBoxCell
    $periodicSendCell.DisplayMember = "Display"
    $periodicSendCell.ValueMember = "Key"
    foreach ($item in $periodicSendItems) {
        [void]$periodicSendCell.Items.Add($item)
    }
    $periodicSendCell.Value = $currentPeriodicSendKey
    $periodicSendCell.Tag = @{
        Mapping               = $periodicSendMapping
        PeriodicSendProfileKey = $currentPeriodicSendKey
    }
    $Row.Cells["PeriodicSend"] = $periodicSendCell
}

function Configure-QuickDataColumn {
    <#
    .SYNOPSIS
    Configures the Quick Data column cell for a connection row.
    #>
    param(
        $Row,
        [string]$InstancePath
    )

    $dataBankEntries = @()
    $dataBankPath = $null
    if ($InstancePath) {
        try {
            $catalog = Get-QuickDataCatalog -InstancePath $InstancePath
            if ($catalog) {
                $dataBankEntries = if ($catalog.Entries) { $catalog.Entries } else { @() }
                $dataBankPath = $catalog.Path
            }
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

    foreach ($item in $dataSource) {
        [void]$quickDataCell.Items.Add($item)
    }
    $quickDataCell.Value = ""
    $quickDataCell.Tag = @{
        DataBankCount = $dataBankEntries.Count
        DataBankPath  = if ($dataBankPath -and (Test-Path -LiteralPath $dataBankPath)) { $dataBankPath } else { $null }
    }
    $Row.Cells["QuickData"] = $quickDataCell
}

function Configure-QuickActionColumn {
    <#
    .SYNOPSIS
    Configures the Quick Action column cell for a connection row.
    #>
    param(
        $Row,
        [string]$InstancePath
    )

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
        [void]$quickActionCell.Items.Add($item)
    }
    $quickActionCell.Value = ""
    $quickActionCell.Tag = @{
        Mapping = $actionMapping
    }
    $Row.Cells["QuickAction"] = $quickActionCell
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
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
        }
        "CONNECTING" {
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow
        }
        "ERROR" {
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightCoral
        }
        "DISCONNECTED" {
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGray
        }
        default {
            $Row.DefaultCellStyle.BackColor = [System.Drawing.Color]::White
        }
    }
}

function Update-LogDisplay {
    <#
    .SYNOPSIS
    Updates the log text box with recent connection messages.
    #>
    param(
        [System.Windows.Forms.TextBox]$TextBox,
        [scriptblock]$GetConnectionsCallback
    )

    if (-not $TextBox) { return }

    $logLines = @()

    try {
        $connections = & $GetConnectionsCallback
    } catch {
        $connections = @()
    }

    foreach ($conn in $connections) {
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

        if (-not $snapshot -or $snapshot.Length -eq 0) { continue }

        $count = $snapshot.Length
        $startIndex = [Math]::Max(0, $count - 10)
        for ($i = $startIndex; $i -lt $count; $i++) {
            $recv = $snapshot[$i]
            if (-not $recv) { continue }

            $summary = Get-MessageSummary -Data $recv.Data -MaxLength 40
            $timeStr = $recv.Timestamp.ToString("HH:mm:ss")
            $logLines += "[$timeStr] $($conn.DisplayName) ← $summary ($($recv.Length) bytes)"
        }
    }

    $logLines = $logLines | Select-Object -Last 100

    $TextBox.Text = $logLines -join "`r`n"
    $TextBox.SelectionStart = $TextBox.Text.Length
    $TextBox.ScrollToCaret()
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

# Note: Export-ModuleMember is not needed when dot-sourcing.
# If this file is imported as a module, uncomment the following:
# Export-ModuleMember -Function @(
#     'New-MainFormWindow',
#     'New-ConnectionDataGridView',
#     'New-ToolbarButton',
#     'New-LabelControl',
#     'New-LogTextBox',
#     'New-RefreshTimer',
#     'Configure-ScenarioColumn',
#     'Configure-OnReceivedColumn',
#     'Configure-PeriodicSendColumn',
#     'Configure-QuickDataColumn',
#     'Configure-QuickActionColumn',
#     'Set-RowColor',
#     'Update-LogDisplay',
#     'Get-MessageSummary'
# )
