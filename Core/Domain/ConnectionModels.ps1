# Core/Domain/ConnectionModels.ps1
# Connection data models used by ConnectionService

. "$PSScriptRoot\VariableScope.ps1"

class ConnectionConfiguration {
    [string]$Id
    [string]$Name
    [string]$DisplayName
    [string]$Description
    [string]$Protocol
    [string]$Mode
    [string]$LocalIP
    [int]$LocalPort
    [string]$RemoteIP
    [int]$RemotePort
    [string]$Group
    [string[]]$Tags
    [bool]$AutoStart
    [string]$AutoScenario
    [string]$DefaultEncoding
    [string]$InstancePath

    ConnectionConfiguration([hashtable]$config) {
        if (-not $config) {
            throw "Connection configuration cannot be null."
        }

        $this.Id = if ($config.Id) { $config.Id } else { [guid]::NewGuid().ToString() }
        $this.Name = $config.Name
        $this.DisplayName = if ($config.DisplayName) { $config.DisplayName } else { $this.Id }
        if (-not $this.Name) {
            $this.Name = $this.DisplayName
        }
        if (-not $this.DisplayName) {
            $this.DisplayName = $this.Name
        }
        $this.Description = $config.Description
        $this.Protocol = if ($config.Protocol) { $config.Protocol.ToUpperInvariant() } else { "TCP" }
        $this.Mode = if ($config.Mode) { $config.Mode } else { "Client" }
        $this.LocalIP = $config.LocalIP
        $this.LocalPort = if ($config.LocalPort) { [int]$config.LocalPort } else { 0 }
        $this.RemoteIP = $config.RemoteIP
        $this.RemotePort = if ($config.RemotePort) { [int]$config.RemotePort } else { 0 }
        $this.Group = $config.Group
        $this.Tags = $config.Tags
        $this.AutoStart = [bool]($config.AutoStart)
        $this.AutoScenario = $config.AutoScenario
        $this.DefaultEncoding = if ($config.DefaultEncoding) { $config.DefaultEncoding } else { "UTF-8" }
        $this.InstancePath = $config.InstancePath
    }
}

class ConnectionRuntimeState {
    hidden [object]$_statusLock
    hidden [string]$_status
    [datetime]$LastActivity
    [string]$ErrorMessage
    [System.Exception]$LastException
    [System.Threading.CancellationTokenSource]$CancellationSource
    [System.Threading.Thread]$WorkerThread
    [object]$Socket

    ConnectionRuntimeState() {
        $this._statusLock = [object]::new()
        $this._status = "IDLE"
        $this.LastActivity = Get-Date
        $this.CancellationSource = [System.Threading.CancellationTokenSource]::new()
    }

    [string] GetStatus() {
        [System.Threading.Monitor]::Enter($this._statusLock)
        try {
            return $this._status
        }
        finally {
            [System.Threading.Monitor]::Exit($this._statusLock)
        }
    }

    [void] SetStatus([string]$status) {
        [System.Threading.Monitor]::Enter($this._statusLock)
        try {
            $this._status = $status
        }
        finally {
            [System.Threading.Monitor]::Exit($this._statusLock)
        }
    }

    [void] SetError([string]$message, [Exception]$exception) {
        $this.ErrorMessage = $message
        $this.LastException = $exception
        $this.SetStatus("ERROR")
    }

    [void] ClearError() {
        $this.ErrorMessage = $null
        $this.LastException = $null
    }
}

class ManagedConnection {
    [ConnectionConfiguration]$Config
    [ConnectionRuntimeState]$State
    [System.Collections.Hashtable]$Variables
    [System.Collections.ArrayList]$SendQueue
    [System.Collections.ArrayList]$RecvBuffer
    [System.Collections.Hashtable]$ScenarioTimers
    [System.Collections.Generic.List[object]]$PeriodicTimers
    [object]$Adapter
    hidden [object]$_propertyLock
    [string]$Id
    [string]$Name
    [string]$DisplayName
    [string]$Protocol
    [string]$Mode
    [string]$LocalIP
    [int]$LocalPort
    [string]$RemoteIP
    [int]$RemotePort
    [string]$Group
    [string[]]$Tags
    [string]$Status
    [string]$ErrorMessage
    [datetime]$LastActivity
    [System.Threading.Thread]$Thread
    [System.Threading.CancellationTokenSource]$CancellationSource
    [object]$Socket

    ManagedConnection(
        [ConnectionConfiguration]$config,
        [object]$adapter,
        [System.Collections.Hashtable]$variables
    ) {
        $this._propertyLock = [object]::new()
        $this.Config = $config
        $this.State = [ConnectionRuntimeState]::new()
        $this.Adapter = $adapter
        if ($variables) {
            $this.Variables = $variables
        } else {
            $this.Variables = [System.Collections.Hashtable]::Synchronized(@{})
        }
        if (-not $this.Variables.ContainsKey('InstancePath') -and $config.InstancePath) {
            $this.Variables['InstancePath'] = $config.InstancePath
        }
        $this.SendQueue = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        $this.RecvBuffer = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
        $this.ScenarioTimers = [System.Collections.Hashtable]::Synchronized(@{})
        $this.PeriodicTimers = New-Object System.Collections.Generic.List[object]
        $this.Id = $config.Id
        $this.Name = if ($config.Name) { $config.Name } else { $config.DisplayName }
        if (-not $this.DisplayName) {
            $this.DisplayName = $this.Name
        }
        $this.Protocol = $config.Protocol
        $this.Mode = $config.Mode
        $this.LocalIP = $config.LocalIP
        $this.LocalPort = $config.LocalPort
        $this.RemoteIP = $config.RemoteIP
        $this.RemotePort = $config.RemotePort
        $this.Group = $config.Group
        $this.Tags = $config.Tags
        $this.Status = "DISCONNECTED"
        $this.LastActivity = Get-Date
        $this.CancellationSource = [System.Threading.CancellationTokenSource]::new()
        $this.Thread = $null
        $this.Socket = $null
        $this.State.CancellationSource = $this.CancellationSource
    }

    [void] UpdateStatus([string]$status) {
        [System.Threading.Monitor]::Enter($this._propertyLock)
        try {
            $this.State.SetStatus($status)
            $this.Status = $status
        }
        finally {
            [System.Threading.Monitor]::Exit($this._propertyLock)
        }
    }

    [void] MarkActivity() {
        [System.Threading.Monitor]::Enter($this._propertyLock)
        try {
            $now = Get-Date
            $this.LastActivity = $now
            $this.State.LastActivity = $now
        }
        finally {
            [System.Threading.Monitor]::Exit($this._propertyLock)
        }
    }

    [void] SetError([string]$message, [Exception]$exception) {
        [System.Threading.Monitor]::Enter($this._propertyLock)
        try {
            $this.ErrorMessage = $message
            $this.State.SetError($message, $exception)
        }
        finally {
            [System.Threading.Monitor]::Exit($this._propertyLock)
        }
    }

    [void] ClearError() {
        [System.Threading.Monitor]::Enter($this._propertyLock)
        try {
            $this.ErrorMessage = $null
            $this.State.ClearError()
        }
        finally {
            [System.Threading.Monitor]::Exit($this._propertyLock)
        }
    }

    [void] SetSocket([object]$socket) {
        [System.Threading.Monitor]::Enter($this._propertyLock)
        try {
            $this.Socket = $socket
            $this.State.Socket = $socket
        }
        finally {
            [System.Threading.Monitor]::Exit($this._propertyLock)
        }
    }

    [void] ClearSocket() {
        [System.Threading.Monitor]::Enter($this._propertyLock)
        try {
            $this.Socket = $null
            $this.State.Socket = $null
        }
        finally {
            [System.Threading.Monitor]::Exit($this._propertyLock)
        }
    }
}
