# AutoResponseManager.ps1
# Helper functions for loading and applying auto-response profiles per instance

function Get-InstanceAutoResponseProfiles {
    <#
    .SYNOPSIS
    Retrieve auto-response profile metadata for an instance folder.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )

    $profilesPath = Join-Path $InstancePath "auto_responses"

    if (-not (Test-Path $profilesPath)) {
        return @()
    }

    $files = Get-ChildItem -Path $profilesPath -Filter "*.csv" -File | Sort-Object Name

    $profiles = foreach ($file in $files) {
        $display = $file.BaseName -replace '[_-]', ' '
        if (-not $display) {
            $display = $file.BaseName
        }

        [PSCustomObject]@{
            Name        = $file.BaseName
            FileName    = $file.Name
            FullPath    = $file.FullName
            DisplayName = $display
        }
    }

    return $profiles
}

function Set-ConnectionAutoResponseProfile {
    <#
    .SYNOPSIS
    Apply an auto-response profile CSV to a connection.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$false)]
        [string]$ProfileFile,

        [switch]$Clear
    )

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }

    $conn = $Global:Connections[$ConnectionId]

    if ($Clear -or -not $ProfileFile) {
        if ($conn.Variables.ContainsKey('ActiveAutoResponseRules')) {
            $conn.Variables.Remove('ActiveAutoResponseRules')
        }
        if ($conn.Variables.ContainsKey('ActiveAutoResponseProfile')) {
            $conn.Variables.Remove('ActiveAutoResponseProfile')
        }
        if ($conn.Variables.ContainsKey('ActiveAutoResponseProfileName')) {
            $conn.Variables.Remove('ActiveAutoResponseProfileName')
        }
        if ($conn.Variables.ContainsKey('ActiveAutoResponseProfilePath')) {
            $conn.Variables.Remove('ActiveAutoResponseProfilePath')
        }

        Write-Host "[AutoResponseManager] Cleared auto-response profile for $($conn.DisplayName)" -ForegroundColor Yellow
        return @()
    }

    if (-not $conn.Variables.ContainsKey('InstancePath')) {
        throw "Instance path not found for connection $($conn.DisplayName)"
    }

    $instancePath = $conn.Variables['InstancePath']
    if (-not $instancePath) {
        throw "Instance path is empty for connection $($conn.DisplayName)"
    }

    $profilesPath = Join-Path $instancePath "auto_responses"
    $profilePath = if ([System.IO.Path]::IsPathRooted($ProfileFile)) {
        $ProfileFile
    } else {
        Join-Path $profilesPath $ProfileFile
    }

    if (-not (Test-Path $profilePath)) {
        throw "Auto-response profile not found: $ProfileFile"
    }

    $rules = Read-AutoResponseRules -FilePath $profilePath

    $profileFileName = [System.IO.Path]::GetFileName($profilePath)
    $profileNameRaw = [System.IO.Path]::GetFileNameWithoutExtension($profilePath)
    $profileName = $profileNameRaw -replace '[_-]', ' '
    if (-not $profileName) {
        $profileName = $profileNameRaw
    }

    $conn.Variables['ActiveAutoResponseRules'] = $rules
    $conn.Variables['ActiveAutoResponseProfile'] = $profileFileName
    $conn.Variables['ActiveAutoResponseProfileName'] = $profileName
    $conn.Variables['ActiveAutoResponseProfilePath'] = (Resolve-Path -Path $profilePath).Path

    Write-Host "[AutoResponseManager] Applied auto-response profile '$profileFileName' to $($conn.DisplayName)" -ForegroundColor Cyan

    return $rules
}

function Clear-ConnectionAutoResponseProfile {
    <#
    .SYNOPSIS
    Clear the active auto-response profile from a connection.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId
    )

    return Set-ConnectionAutoResponseProfile -ConnectionId $ConnectionId -Clear
}
