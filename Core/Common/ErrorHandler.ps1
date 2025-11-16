# Core/Common/ErrorHandler.ps1
# Centralized error-handling helpers

class ErrorHandler {
    [Logger]$Logger

    ErrorHandler([Logger]$logger) {
        if (-not $logger) {
            throw "Logger is required for ErrorHandler."
        }
        $this.Logger = $logger
    }

    [object] InvokeSafe(
        [scriptblock]$Operation,
        [string]$OperationName,
        [hashtable]$Context = @{},
        [switch]$Rethrow
    ) {
        if (-not $Operation) {
            throw "Operation cannot be null."
        }

        $name = if ($OperationName) { $OperationName } else { "Operation" }

        try {
            return & $Operation
        }
        catch {
            $errorRecord = $_
            $exception = $errorRecord.Exception
            if (-not $Context) { $Context = @{} }

            $Context['Operation'] = $name
            $Context['ErrorRecord'] = $errorRecord.ToString()

            $this.Logger.LogError("Error executing $name", $exception, $Context)

            if ($Rethrow) {
                throw
            }

            return $null
        }
    }
}

function Invoke-WithErrorHandling {
    param(
        [Parameter(Mandatory = $true)]
        [ErrorHandler]$Handler,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},

        [switch]$Rethrow
    )

    return $Handler.InvokeSafe($Operation, $Name, $Context, $Rethrow)
}
