# Core/Common/ConsoleOutput.ps1
# Shared terminal output helper that honors the global EnableConsoleOutput flag

function Write-Console {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object]$Message = "",

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White,

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$BackgroundColor,

        [switch]$NoNewline,

        [switch]$Force
    )

    begin {
        $script:__writeConsoleEnabled = $true
        $enableVar = $null
        try {
            $enableVar = Get-Variable -Name EnableConsoleOutput -Scope Global -ValueOnly -ErrorAction Stop
        } catch {
            $enableVar = $null
        }

        if ($null -ne $enableVar) {
            $script:__writeConsoleEnabled = [bool]$enableVar
        }
    }

    process {
        if (-not $Force -and -not $script:__writeConsoleEnabled) {
            return
        }

        if ($null -eq $Message) {
            $Message = ""
        }

        $params = @{ ForegroundColor = $ForegroundColor }

        if ($PSBoundParameters.ContainsKey('BackgroundColor')) {
            $params['BackgroundColor'] = $BackgroundColor
        }

        if ($NoNewline.IsPresent) {
            $params['NoNewline'] = $true
        }

        Write-Host ([string]$Message) @params
    }
}

function Write-DebugLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White
    )

    Write-Console -Message $Message -ForegroundColor $ForegroundColor
}

Set-Alias -Name Write-AppConsole -Value Write-Console -Scope Global
Set-Alias -Name Write-TerminalLog -Value Write-Console -Scope Global
