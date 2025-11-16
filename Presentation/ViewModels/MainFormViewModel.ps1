# MainFormViewModel.ps1
# ViewModel for the main form - separates UI state and business logic from presentation

class MainFormViewModel {
    # Observable properties
    [System.Collections.ArrayList]$Connections
    [string]$SelectedConnectionId
    [System.Collections.ArrayList]$LogEntries
    [bool]$IsRefreshing
    
    # Services (dependency injection)
    [object]$ConnectionService
    [object]$InstanceManager
    [object]$MessageService
    
    # Event handlers storage
    [scriptblock]$OnPropertyChanged
    
    MainFormViewModel([object]$connectionService, [object]$instanceManager, [object]$messageService) {
        $this.ConnectionService = $connectionService
        $this.InstanceManager = $instanceManager
        $this.MessageService = $messageService
        $this.Connections = New-Object System.Collections.ArrayList
        $this.LogEntries = New-Object System.Collections.ArrayList
        $this.SelectedConnectionId = $null
        $this.IsRefreshing = $false
    }
    
    # Refresh connection list
    [void] RefreshConnections() {
        $this.IsRefreshing = $true
        $this.Connections.Clear()
        
        try {
            $allConnections = $this.ConnectionService.GetAllConnections()
            foreach ($conn in $allConnections) {
                [void]$this.Connections.Add($conn)
            }
        } catch {
            Write-Error "Failed to refresh connections: $_"
        } finally {
            $this.IsRefreshing = $false
        }
        
        $this.NotifyPropertyChanged('Connections')
    }
    
    # Get selected connection object
    [object] GetSelectedConnection() {
        if ([string]::IsNullOrWhiteSpace($this.SelectedConnectionId)) {
            return $null
        }
        
        try {
            return $this.ConnectionService.GetConnection($this.SelectedConnectionId)
        } catch {
            return $null
        }
    }
    
    # Connect selected connection
    [void] ConnectSelectedConnection() {
        $conn = $this.GetSelectedConnection()
        if (-not $conn) {
            throw "No connection selected"
        }
        
        Start-Connection -ConnectionId $conn.Id
    }
    
    # Disconnect selected connection
    [void] DisconnectSelectedConnection() {
        $conn = $this.GetSelectedConnection()
        if (-not $conn) {
            throw "No connection selected"
        }
        
        Stop-Connection -ConnectionId $conn.Id
    }
    
    # Set auto-response profile for a connection
    [void] SetAutoResponseProfile([string]$connectionId, [string]$profileName, [string]$profilePath) {
        Set-ConnectionAutoResponseProfile -ConnectionId $connectionId -ProfileName $profileName -ProfilePath $profilePath
    }
    
    # Set OnReceived profile for a connection
    [void] SetOnReceivedProfile([string]$connectionId, [string]$profileName, [string]$profilePath) {
        Set-ConnectionOnReceivedProfile -ConnectionId $connectionId -ProfileName $profileName -ProfilePath $profilePath
    }
    
    # Set Periodic Send profile for a connection
    [void] SetPeriodicSendProfile([string]$connectionId, [string]$profilePath, [string]$instancePath) {
        Set-ConnectionPeriodicSendProfile -ConnectionId $connectionId -ProfilePath $profilePath -InstancePath $instancePath
    }
    
    # Start a scenario
    [void] StartScenario([string]$connectionId, [string]$scenarioPath) {
        if (-not (Test-Path -LiteralPath $scenarioPath)) {
            throw "Scenario file not found: $scenarioPath"
        }
        
        Start-Scenario -ConnectionId $connectionId -ScenarioPath $scenarioPath
    }
    
    # Send quick data
    [void] SendQuickData([string]$connectionId, [string]$dataId, [string]$dataBankPath) {
        if ([string]::IsNullOrWhiteSpace($dataBankPath) -or -not (Test-Path -LiteralPath $dataBankPath)) {
            throw "Data bank file not found: $dataBankPath"
        }
        
        Send-QuickData -ConnectionId $connectionId -DataID $dataId -DataBankPath $dataBankPath
    }
    
    # Get quick data catalog for a connection
    [hashtable] GetQuickDataCatalog([string]$instancePath) {
        if (-not $instancePath -or -not (Test-Path -LiteralPath $instancePath)) {
            return @{}
        }
        
        try {
            return Get-QuickDataCatalog -InstancePath $instancePath
        } catch {
            Write-Error "Failed to get quick data catalog: $_"
            return @{}
        }
    }
    
    # Get profile catalog for auto-response
    [hashtable] GetAutoResponseProfileCatalog([string]$instancePath) {
        if (-not $instancePath -or -not (Test-Path -LiteralPath $instancePath)) {
            return @{}
        }
        
        $scenariosPath = Join-Path $instancePath "scenarios"
        if (-not (Test-Path -LiteralPath $scenariosPath)) {
            return @{}
        }
        
        $catalog = @{}
        
        # Add "(None)" option
        $catalog[""] = @{
            Key = ""
            Display = "(None)"
            Type = "None"
            Name = $null
            Path = $null
        }
        
        # Add scenario files
        try {
            $csvFiles = Get-ChildItem -LiteralPath $scenariosPath -Filter "*.csv" -File -ErrorAction SilentlyContinue
            foreach ($file in $csvFiles) {
                $key = "scenario:$($file.BaseName)"
                $catalog[$key] = @{
                    Key = $key
                    Display = "[Scenario] $($file.BaseName)"
                    Type = "Scenario"
                    Name = $file.BaseName
                    Path = $file.FullName
                }
            }
        } catch {
            Write-Warning "Failed to enumerate scenario files: $_"
        }
        
        # Add auto folder (unified rules)
        $autoPath = Join-Path $scenariosPath "auto"
        if (Test-Path -LiteralPath $autoPath) {
            try {
                $autoFiles = Get-ChildItem -LiteralPath $autoPath -Filter "*.csv" -File -ErrorAction SilentlyContinue
                foreach ($file in $autoFiles) {
                    $key = "profile:auto:$($file.BaseName)"
                    $catalog[$key] = @{
                        Key = $key
                        Display = "[Auto] $($file.BaseName)"
                        Type = "Profile"
                        Name = $file.BaseName
                        Path = $file.FullName
                    }
                }
            } catch {
                Write-Warning "Failed to enumerate auto profile files: $_"
            }
        }
        
        return $catalog
    }
    
    # Get profile catalog for OnReceived
    [hashtable] GetOnReceivedProfileCatalog([string]$instancePath) {
        if (-not $instancePath -or -not (Test-Path -LiteralPath $instancePath)) {
            return @{}
        }
        
        $onReceivedPath = Join-Path (Join-Path $instancePath "scenarios") "onreceived"
        if (-not (Test-Path -LiteralPath $onReceivedPath)) {
            return @{}
        }
        
        $catalog = @{}
        
        # Add "(None)" option
        $catalog[""] = @{
            Key = ""
            Display = "(None)"
            Type = "None"
            Name = $null
            Path = $null
        }
        
        # Find rules.csv file
        $rulesPath = Join-Path $onReceivedPath "rules.csv"
        if (Test-Path -LiteralPath $rulesPath) {
            $catalog["profile:onreceived:rules"] = @{
                Key = "profile:onreceived:rules"
                Display = "OnReceived Rules"
                Type = "Profile"
                Name = "rules"
                Path = $rulesPath
            }
        }
        
        return $catalog
    }
    
    # Get profile catalog for Periodic Send
    [hashtable] GetPeriodicSendProfileCatalog([string]$instancePath) {
        if (-not $instancePath -or -not (Test-Path -LiteralPath $instancePath)) {
            return @{}
        }
        
        $periodicPath = Join-Path (Join-Path $instancePath "scenarios") "periodic"
        if (-not (Test-Path -LiteralPath $periodicPath)) {
            return @{}
        }
        
        $catalog = @{}
        
        # Add "(None)" option
        $catalog[""] = @{
            Key = ""
            Display = "(None)"
            Type = "None"
            Name = $null
            Path = $null
        }
        
        # Add all CSV files in periodic folder
        try {
            $csvFiles = Get-ChildItem -LiteralPath $periodicPath -Filter "*.csv" -File -ErrorAction SilentlyContinue
            foreach ($file in $csvFiles) {
                $key = "profile:periodic:$($file.BaseName)"
                $catalog[$key] = @{
                    Key = $key
                    Display = $file.BaseName
                    Type = "Profile"
                    Name = $file.BaseName
                    Path = $file.FullName
                }
            }
        } catch {
            Write-Warning "Failed to enumerate periodic send files: $_"
        }
        
        return $catalog
    }
    
    # Get quick action catalog
    [hashtable] GetQuickActionCatalog([string]$instancePath) {
        if (-not $instancePath -or -not (Test-Path -LiteralPath $instancePath)) {
            return @{}
        }
        
        $scenariosPath = Join-Path $instancePath "scenarios"
        if (-not (Test-Path -LiteralPath $scenariosPath)) {
            return @{}
        }
        
        $catalog = @{}
        
        # Add "(Select Action)" option
        $catalog[""] = @{
            Key = ""
            Display = "(Select Action)"
            Type = "None"
            Name = $null
            Path = $null
        }
        
        # Add scenario files as actions
        try {
            $csvFiles = Get-ChildItem -LiteralPath $scenariosPath -Filter "*.csv" -File -ErrorAction SilentlyContinue
            foreach ($file in $csvFiles) {
                $key = "scenario:$($file.BaseName)"
                $catalog[$key] = @{
                    Key = $key
                    Display = $file.BaseName
                    Type = "Scenario"
                    Name = $file.BaseName
                    Path = $file.FullName
                }
            }
        } catch {
            Write-Warning "Failed to enumerate scenario files for quick actions: $_"
        }
        
        return $catalog
    }
    
    # Add log entry
    [void] AddLogEntry([string]$message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $entry = "[$timestamp] $message"
        
        [void]$this.LogEntries.Add($entry)
        
        # Keep only last 1000 entries
        while ($this.LogEntries.Count -gt 1000) {
            $this.LogEntries.RemoveAt(0)
        }
        
        $this.NotifyPropertyChanged('LogEntries')
    }
    
    # Clear log entries
    [void] ClearLogs() {
        $this.LogEntries.Clear()
        $this.NotifyPropertyChanged('LogEntries')
    }
    
    # Cleanup on form closing
    [void] Cleanup() {
        foreach ($conn in $this.ConnectionService.GetAllConnections()) {
            try {
                Stop-Connection -ConnectionId $conn.Id -Force
            } catch {
                # Ignore errors during cleanup
            }
        }
    }
    
    # Property change notification
    [void] NotifyPropertyChanged([string]$propertyName) {
        if ($this.OnPropertyChanged) {
            & $this.OnPropertyChanged $propertyName
        }
    }
}

function New-MainFormViewModel {
    <#
    .SYNOPSIS
    Creates a new MainFormViewModel instance.
    
    .DESCRIPTION
    Factory function to create a MainFormViewModel with proper dependency injection.
    
    .PARAMETER ConnectionService
    The connection service instance.
    
    .PARAMETER InstanceManager
    The instance manager service.
    
    .PARAMETER MessageService
    The message service instance.
    
    .EXAMPLE
    $viewModel = New-MainFormViewModel -ConnectionService $connSvc -InstanceManager $instMgr -MessageService $msgSvc
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$ConnectionService,
        
        [Parameter(Mandatory = $true)]
        [object]$InstanceManager,
        
        [Parameter(Mandatory = $true)]
        [object]$MessageService
    )
    
    return [MainFormViewModel]::new($ConnectionService, $InstanceManager, $MessageService)
}

Export-ModuleMember -Function New-MainFormViewModel
