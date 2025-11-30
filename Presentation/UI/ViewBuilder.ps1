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
    $dgv.SelectionMode = "CellSelect"
    $dgv.MultiSelect = $false
    $dgv.AutoSizeColumnsMode = "Fill"
    $dgv.AutoGenerateColumns = $false
    $dgv.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter

    # Disable visual selection
    $dgv.DefaultCellStyle.BackColor = [System.Drawing.SystemColors]::Window
    $dgv.DefaultCellStyle.ForeColor = [System.Drawing.SystemColors]::WindowText
    $dgv.DefaultCellStyle.SelectionBackColor = [System.Drawing.SystemColors]::Window
    $dgv.DefaultCellStyle.SelectionForeColor = [System.Drawing.SystemColors]::WindowText

    # Suppress focus rectangle and selection highlight via CellPainting
    $dgv.Add_CellPainting({
        param($sender, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -ge 0) {
            # Remove Focus and SelectionBackground from paint parts while preserving others
            $parts = $e.PaintParts
            if (($parts -band [System.Windows.Forms.DataGridViewPaintParts]::Focus) -ne 0) {
                $parts = $parts -bxor [System.Windows.Forms.DataGridViewPaintParts]::Focus
            }
            if (($parts -band [System.Windows.Forms.DataGridViewPaintParts]::SelectionBackground) -ne 0) {
                $parts = $parts -bxor [System.Windows.Forms.DataGridViewPaintParts]::SelectionBackground
            }

            # Force unselected colors just in case
            $e.CellStyle.SelectionBackColor = $e.CellStyle.BackColor
            $e.CellStyle.SelectionForeColor = $e.CellStyle.ForeColor

            $e.Paint($e.CellBounds, $parts)
            $e.Handled = $true
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

    # Connect button column
    $colConnect = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colConnect.HeaderText = "Connect"
    $colConnect.Name = "BtnConnect"
    $colConnect.Text = "Connect"
    $colConnect.UseColumnTextForButtonValue = $true
    $colConnect.FillWeight = 80
    [void]$DataGridView.Columns.Add($colConnect)

    # Disconnect button column
    $colDisconnect = New-Object System.Windows.Forms.DataGridViewButtonColumn
    $colDisconnect.HeaderText = "Disconnect"
    $colDisconnect.Name = "BtnDisconnect"
    $colDisconnect.Text = "Disconnect"
    $colDisconnect.UseColumnTextForButtonValue = $true
    $colDisconnect.FillWeight = 80
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
    $colOnReceiveReply.HeaderText = "On Receive: Reply"
    $colOnReceiveReply.Name = "Scenario"
    $colOnReceiveReply.DisplayMember = "Display"
    $colOnReceiveReply.ValueMember = "Key"
    $colOnReceiveReply.ValueType = [string]
    $colOnReceiveReply.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnReceiveReply.FillWeight = 140
    [void]$DataGridView.Columns.Add($colOnReceiveReply)

    # On Receive: Script column (ComboBox)
    $colOnReceiveScript = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnReceiveScript.HeaderText = "On Receive: Script"
    $colOnReceiveScript.Name = "OnReceiveScript"
    $colOnReceiveScript.DisplayMember = "Display"
    $colOnReceiveScript.ValueMember = "Key"
    $colOnReceiveScript.ValueType = [string]
    $colOnReceiveScript.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnReceiveScript.FillWeight = 140
    [void]$DataGridView.Columns.Add($colOnReceiveScript)

    # On Timer: Send column (ComboBox)
    $colOnTimerSend = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colOnTimerSend.HeaderText = "On Timer: Send"
    $colOnTimerSend.Name = "OnTimerSend"
    $colOnTimerSend.DisplayMember = "Display"
    $colOnTimerSend.ValueMember = "Key"
    $colOnTimerSend.ValueType = [string]
    $colOnTimerSend.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $colOnTimerSend.FillWeight = 140
    [void]$DataGridView.Columns.Add($colOnTimerSend)

    # Manual: Send column (ComboBox)
    $colManualSend = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colManualSend.HeaderText = "Manual: Send"
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
    $colQuickSend.Text = "Send"
    $colQuickSend.UseColumnTextForButtonValue = $true
    $colQuickSend.FillWeight = 70
    [void]$DataGridView.Columns.Add($colQuickSend)

    # Manual: Script column (ComboBox)
    $colManualScript = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
    $colManualScript.HeaderText = "Manual: Script"
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
#     'New-RefreshTimer',
#     'Configure-ScenarioColumn',
#     'Configure-OnReceiveScriptColumn',
#     'Configure-OnTimerSendColumn',
#     'Configure-ManualSendColumn',
#     'Configure-ManualScriptColumn',
#     'Set-RowColor',
#     'Get-MessageSummary'
# )
