# Tests/Unit/Core/Common/Logger.Tests.ps1

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")
. (Join-Path $repoRoot "Core\Common\Logger.ps1")

Describe 'Logger' {
    BeforeEach {
        $script:TestLogPath = Join-Path $PSScriptRoot "logger-test.log"
        if (Test-Path -LiteralPath $script:TestLogPath) {
            Remove-Item -LiteralPath $script:TestLogPath -Force
        }
        $script:Logger = [Logger]::new($script:TestLogPath, "TestLogger")
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TestLogPath) {
            Remove-Item -LiteralPath $script:TestLogPath -Force
        }
    }

    It 'writes json entry for info messages' {
        $script:Logger.LogInfo("Hello world", @{ ConnectionId = "conn-1" })

        $lines = Get-Content -LiteralPath $script:TestLogPath
        ($lines | Measure-Object).Count | Should Be 1

        $entry = $lines | ConvertFrom-Json
        $entry.Message | Should Be "Hello world"
        $entry.Context.ConnectionId | Should Be "conn-1"
        $entry.Level | Should Be "INFO"
    }

    It 'captures exception metadata' {
        try {
            throw [System.InvalidOperationException]::new("Boom")
        }
        catch {
            $script:Logger.LogError("Failure", $_.Exception, @{})
        }

        $entry = (Get-Content -LiteralPath $script:TestLogPath) | ConvertFrom-Json
        $entry.Context.Exception | Should Match "InvalidOperationException"
        $entry.Context.ExceptionMessage | Should Be "Boom"
    }
}
