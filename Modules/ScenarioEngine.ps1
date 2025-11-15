# ScenarioEngine.ps1
# シナリオ実行エンジン - CSV形式シナリオの読み込みと実行

function Read-ScenarioFile {
    <#
    .SYNOPSIS
    CSVシナリオファイルを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "Scenario file not found: $FilePath"
    }
    
    Write-Host "[ScenarioEngine] Loading scenario: $FilePath" -ForegroundColor Cyan
    
    # CSV読み込み
    $steps = Import-Csv -Path $FilePath -Encoding UTF8
    
    Write-Host "[ScenarioEngine] Loaded $($steps.Count) steps" -ForegroundColor Green
    
    return $steps
}

function Start-Scenario {
    <#
    .SYNOPSIS
    シナリオを実行
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [string]$ScenarioPath
    )

    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }

    # Load scenario file
    $scenarioSteps = Read-ScenarioFile -FilePath $ScenarioPath

    $scriptBlock = {
        param(
            [string]$ConnectionId,
            [object[]]$ScenarioSteps
        )

        if (-not $Global:Connections.ContainsKey($ConnectionId)) {
            Write-Error "[ScenarioEngine] Connection not found inside scenario thread: $ConnectionId"
            return
        }

        $connection = $Global:Connections[$ConnectionId]
        $totalSteps = if ($ScenarioSteps) { $ScenarioSteps.Count } else { 0 }
        $loopStack = New-Object System.Collections.Generic.List[object]

        try {
            $stopScenario = $false
            for ($index = 0; $index -lt $ScenarioSteps.Count; $index++) {
                $step = $ScenarioSteps[$index]
                $currentStep = $index + 1

                if ($connection.CancellationSource -and $connection.CancellationSource.Token.IsCancellationRequested) {
                    Write-Host "[ScenarioEngine] Scenario cancelled" -ForegroundColor Yellow
                    break
                }

                Write-Host "[ScenarioEngine] Step $currentStep/$totalSteps : $($step.Action)" -ForegroundColor Cyan

                $action = if ($step.Action) { $step.Action.ToUpperInvariant() } else { "" }

                switch ($action) {
                    "SEND" {
                        Invoke-SendAction -Connection $connection -Step $step
                    }
                    "SEND_HEX" {
                        Invoke-SendHexAction -Connection $connection -Step $step
                    }
                    "SEND_FILE" {
                        Invoke-SendFileAction -Connection $connection -Step $step
                    }
                    "WAIT_RECV" {
                        Invoke-WaitRecvAction -Connection $connection -Step $step
                    }
                    "SAVE_RECV" {
                        Invoke-SaveRecvAction -Connection $connection -Step $step
                    }
                    "SLEEP" {
                        Invoke-SleepAction -Connection $connection -Step $step
                    }
                    "SET_VAR" {
                        Invoke-SetVarAction -Connection $connection -Step $step
                    }
                    "IF" {
                        Invoke-IfAction -Connection $connection -Step $step
                    }
                    "LOOP" {
                        $indexRef = [ref]$index
                        $loopStackRef = [ref]$loopStack
                        $result = Invoke-LoopAction -Connection $connection -Step $step -ScenarioSteps $ScenarioSteps -CurrentIndex $indexRef -CurrentStepIndex $currentStep -LoopStack $loopStackRef
                        $index = $indexRef.Value
                        if ($result.ShouldBreak) {
                            $stopScenario = $true
                            break
                        }
                    }
                    "CALL_SCRIPT" {
                        Invoke-CallScriptAction -Connection $connection -Step $step
                    }
                    "DISCONNECT" {
                        Stop-Connection -ConnectionId $ConnectionId
                        $stopScenario = $true
                        break
                    }
                    "RECONNECT" {
                        Stop-Connection -ConnectionId $ConnectionId
                        Start-Sleep -Seconds 1
                        Start-Connection -ConnectionId $ConnectionId
                    }
                    default {
                        Write-Warning "Unknown action: $($step.Action)"
                    }
                }

                if ($stopScenario) {
                    break
                }
            }

            Write-Host "[ScenarioEngine] Scenario completed successfully" -ForegroundColor Green
        } catch {
            Write-Error "[ScenarioEngine] Scenario execution error: $_"
        }
    }

    # スレッド開始
    $targetConnectionId = $ConnectionId
    $localScenarioSteps = @($scenarioSteps)
    $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
        & $scriptBlock -ConnectionId $targetConnectionId -ScenarioSteps $localScenarioSteps
    })

    $thread.IsBackground = $true
    $thread.Start()

    Write-Host "[ScenarioEngine] Scenario thread started" -ForegroundColor Green
}

# アクション実装

function Invoke-SendAction {
    param($Connection, $Step)
    
    # テンプレート展開
    $message = Expand-MessageVariables -Template $Step.Parameter1 -Variables $Connection.Variables
    
    # バイト配列に変換
    $encoding = if ($Step.Parameter2) { $Step.Parameter2 } else { "UTF-8" }
    $bytes = ConvertTo-ByteArray -Data $message -Encoding $encoding
    
    # 送信キューに追加
    Send-Data -ConnectionId $Connection.Id -Data $bytes
    
    Write-Host "[ScenarioEngine] Sent: $message" -ForegroundColor Blue
}

function Invoke-SendHexAction {
    param($Connection, $Step)
    
    # HEX文字列をバイト配列に変換
    $bytes = ConvertTo-ByteArray -Data $Step.Parameter1 -IsHex
    
    # 送信キューに追加
    Send-Data -ConnectionId $Connection.Id -Data $bytes
    
    Write-Host "[ScenarioEngine] Sent HEX: $($Step.Parameter1)" -ForegroundColor Blue
}

function Invoke-SendFileAction {
    param($Connection, $Step)
    
    $filePath = $Step.Parameter1
    
    if (-not (Test-Path $filePath)) {
        Write-Error "File not found: $filePath"
        return
    }
    
    # ファイル読み込み
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    
    # 送信キューに追加
    Send-Data -ConnectionId $Connection.Id -Data $bytes
    
    Write-Host "[ScenarioEngine] Sent file: $filePath ($($bytes.Length) bytes)" -ForegroundColor Blue
}

function Invoke-WaitRecvAction {
    param($Connection, $Step)
    
    # パラメータ解析
    $timeout = 5000  # デフォルト5秒
    $pattern = $null
    
    if ($Step.Parameter1 -like "TIMEOUT=*") {
        $timeout = [int]($Step.Parameter1 -replace 'TIMEOUT=', '')
    }
    
    if ($Step.Parameter2 -like "PATTERN=*") {
        $pattern = $Step.Parameter2 -replace 'PATTERN=', ''
    }
    
    Write-Host "[ScenarioEngine] Waiting for receive (timeout: ${timeout}ms, pattern: $pattern)..." -ForegroundColor Cyan
    
    $startTime = Get-Date
    $received = $false
    
    while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout) {
        if ($Connection.RecvBuffer.Count -gt 0) {
            $lastRecv = $Connection.RecvBuffer[-1]
            $recvText = ConvertFrom-ByteArray -Data $lastRecv.Data -Encoding "UTF-8"
            
            # パターンマッチング
            if ($pattern) {
                if ($recvText -like "*$pattern*") {
                    $received = $true
                    Write-Host "[ScenarioEngine] Pattern matched: $pattern" -ForegroundColor Green
                    break
                }
            } else {
                $received = $true
                Write-Host "[ScenarioEngine] Data received" -ForegroundColor Green
                break
            }
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    if (-not $received) {
        Write-Warning "[ScenarioEngine] Receive timeout"
    }
}

function Invoke-SaveRecvAction {
    param($Connection, $Step)
    
    $varName = $Step.Parameter1
    if ($Step.Parameter1 -like "VAR_NAME=*") {
        $varName = $Step.Parameter1 -replace 'VAR_NAME=', ''
    }
    
    if ($Connection.RecvBuffer.Count -gt 0) {
        $lastRecv = $Connection.RecvBuffer[-1]
        $recvText = ConvertFrom-ByteArray -Data $lastRecv.Data -Encoding "UTF-8"
        
        # 変数に保存
        $Connection.Variables[$varName] = $recvText
        
        Write-Host "[ScenarioEngine] Saved to variable '$varName': $recvText" -ForegroundColor Green
    } else {
        Write-Warning "[ScenarioEngine] No data to save"
    }
}

function Invoke-SleepAction {
    param($Connection, $Step)
    
    $milliseconds = [int]$Step.Parameter1
    
    Write-Host "[ScenarioEngine] Sleeping for ${milliseconds}ms..." -ForegroundColor Cyan
    Start-Sleep -Milliseconds $milliseconds
}

function Invoke-SetVarAction {
    param($Connection, $Step)

    $varName = $Step.Parameter1
    $varValue = $Step.Parameter2

    if ($varName -like "VAR_NAME=*") {
        $varName = $varName -replace '^VAR_NAME=', ''
    }

    if ($varValue -like "VALUE=*") {
        $varValue = $varValue -replace '^VALUE=', ''
    }

    if ([string]::IsNullOrWhiteSpace($varName)) {
        Write-Warning "[ScenarioEngine] SET_VAR requires a variable name"
        return
    }

    $expandedValue = Expand-MessageVariables -Template $varValue -Variables $Connection.Variables

    $Connection.Variables[$varName] = $expandedValue

    Write-Host "[ScenarioEngine] Set variable '$varName' = '$expandedValue'" -ForegroundColor Green
}
    
function Invoke-LoopAction {
    param(
        $Connection,
        $Step,
        [object[]]$ScenarioSteps,
        [ref]$CurrentIndex,
        [int]$CurrentStepIndex,
        [ref]$LoopStack
    )

    $result = [pscustomobject]@{
        ShouldBreak = $false
    }

    $token = $null
    if ($Connection -and $Connection.CancellationSource) {
        $token = $Connection.CancellationSource.Token
    }

    $normalizedParams = @()
    foreach ($value in @($Step.Parameter1, $Step.Parameter2, $Step.Parameter3)) {
        if ($null -ne $value) {
            $textValue = $value.ToString().Trim()
            if ($textValue) {
                $normalizedParams += $textValue
            }
        }
    }

    $primaryToken = if ($normalizedParams.Count -gt 0) { $normalizedParams[0].ToUpperInvariant() } else { "" }

    if ($primaryToken -in @("BEGIN", "START")) {
        $loopCount = Get-LoopCountFromParameters @($Step.Parameter2, $Step.Parameter3)
        if ($loopCount -ne $null -and $loopCount -lt 1) {
            Write-Warning "[ScenarioEngine] LOOP count must be greater than zero. Using 1 instead."
            $loopCount = 1
        }

        $loopLabel = Get-LoopLabelFromParameters @($Step.Parameter1, $Step.Parameter2, $Step.Parameter3)
        $labelInfo = if ([string]::IsNullOrWhiteSpace($loopLabel)) { "(auto)" } else { $loopLabel }
        $countInfo = if ($loopCount) { $loopCount } else { "infinite" }

        $entry = [pscustomobject]@{
            Mode = "Block"
            Label = $loopLabel
            StartIndex = $CurrentIndex.Value
            TotalCount = $loopCount
            Completed = 0
            Step = $CurrentStepIndex
        }

        [void]$LoopStack.Value.Add($entry)

        Write-Host "[ScenarioEngine] LOOP start (step $CurrentStepIndex, label: $labelInfo, count: $countInfo)" -ForegroundColor Cyan
        return $result
    }

    if ($primaryToken -eq "END") {
        if ($LoopStack.Value.Count -eq 0) {
            Write-Warning "[ScenarioEngine] LOOP END encountered without matching start (step $CurrentStepIndex)"
            return $result
        }

        $labelFilter = Get-LoopLabelFromParameters @($Step.Parameter1, $Step.Parameter2, $Step.Parameter3)

        $entryIndex = $null
        for ($i = $LoopStack.Value.Count - 1; $i -ge 0; $i--) {
            $candidate = $LoopStack.Value[$i]
            if ($candidate.Mode -ne "Block") {
                continue
            }

            if ($labelFilter -and $candidate.Label -ne $labelFilter) {
                continue
            }

            $entryIndex = $i
            break
        }

        if ($null -eq $entryIndex) {
            Write-Warning "[ScenarioEngine] LOOP END label '$labelFilter' not found (step $CurrentStepIndex)"
            return $result
        }

        $entry = $LoopStack.Value[$entryIndex]
        $entry.Completed++

        $labelInfo = if ([string]::IsNullOrWhiteSpace($entry.Label)) { "(auto)" } else { $entry.Label }

        if ($entry.TotalCount) {
            if ($entry.Completed -lt $entry.TotalCount) {
                $LoopStack.Value[$entryIndex] = $entry
                $CurrentIndex.Value = $entry.StartIndex
                $remaining = $entry.TotalCount - $entry.Completed
                Write-Host "[ScenarioEngine] LOOP continue (label: $labelInfo, remaining: $remaining)" -ForegroundColor Cyan
            } else {
                $LoopStack.Value.RemoveAt($entryIndex)
                Write-Host "[ScenarioEngine] LOOP completed (label: $labelInfo)" -ForegroundColor Green
            }
        } else {
            if ($token -and $token.IsCancellationRequested) {
                $LoopStack.Value.RemoveAt($entryIndex)
                $result.ShouldBreak = $true
                Write-Host "[ScenarioEngine] LOOP cancelled (label: $labelInfo)" -ForegroundColor Yellow
            } else {
                $LoopStack.Value[$entryIndex] = $entry
                $CurrentIndex.Value = $entry.StartIndex
                Write-Host "[ScenarioEngine] LOOP continue (label: $labelInfo, iterations completed: $($entry.Completed))" -ForegroundColor Cyan
            }
        }

        return $result
    }

    $startIndex = Get-StepIndexFromParameter $Step.Parameter1
    if ($null -eq $startIndex) {
        Write-Warning "[ScenarioEngine] LOOP parameters not understood at step $CurrentStepIndex"
        return $result
    }

    $loopCount = Get-LoopCountFromParameters @($Step.Parameter3, $Step.Parameter2)
    if ($loopCount -ne $null -and $loopCount -lt 1) {
        Write-Warning "[ScenarioEngine] LOOP count must be greater than zero. Using 1 instead."
        $loopCount = 1
    }

    $legacyEntryIndex = $null
    for ($i = 0; $i -lt $LoopStack.Value.Count; $i++) {
        $candidate = $LoopStack.Value[$i]
        if ($candidate.Mode -eq "Legacy" -and $candidate.EndIndex -eq ($CurrentStepIndex - 1)) {
            $legacyEntryIndex = $i
            break
        }
    }

    if ($null -eq $legacyEntryIndex) {
        $entry = [pscustomobject]@{
            Mode = "Legacy"
            StartIndex = $startIndex
            EndIndex = $CurrentStepIndex - 1
            TotalCount = $loopCount
            Completed = 0
        }

        [void]$LoopStack.Value.Add($entry)
        $legacyEntryIndex = $LoopStack.Value.Count - 1
    }

    $entry = $LoopStack.Value[$legacyEntryIndex]
    $entry.Completed++

    if ($entry.TotalCount) {
        if ($entry.Completed -lt $entry.TotalCount) {
            $LoopStack.Value[$legacyEntryIndex] = $entry
            $CurrentIndex.Value = $entry.StartIndex
            $remaining = $entry.TotalCount - $entry.Completed
            Write-Host "[ScenarioEngine] LOOP continue (legacy, remaining: $remaining)" -ForegroundColor Cyan
        } else {
            $LoopStack.Value.RemoveAt($legacyEntryIndex)
            Write-Host "[ScenarioEngine] LOOP completed (legacy)" -ForegroundColor Green
        }
    } else {
        if ($token -and $token.IsCancellationRequested) {
            $LoopStack.Value.RemoveAt($legacyEntryIndex)
            $result.ShouldBreak = $true
            Write-Host "[ScenarioEngine] LOOP cancelled (legacy)" -ForegroundColor Yellow
        } else {
            $LoopStack.Value[$legacyEntryIndex] = $entry
            $CurrentIndex.Value = $entry.StartIndex
            Write-Host "[ScenarioEngine] LOOP continue (legacy iterations completed: $($entry.Completed))" -ForegroundColor Cyan
        }
    }

    return $result
}


function Get-LoopCountFromParameters {
    param(
        [object[]]$Values
    )

    foreach ($value in $Values) {
        if ($null -eq $value) {
            continue
        }

        $text = $value.ToString().Trim()
        if (-not $text) {
            continue
        }

        if ($text -match '^COUNT\s*=\s*(\d+)$') {
            return [int]$Matches[1]
        }

        if ($text -match '^TIMES\s*=\s*(\d+)$') {
            return [int]$Matches[1]
        }

        if ($text -match '^REPEAT\s*=\s*(\d+)$') {
            return [int]$Matches[1]
        }

        if ($text -match '^\d+$') {
            return [int]$text
        }
    }

    return $null
}

function Get-LoopLabelFromParameters {
    param(
        [object[]]$Values
    )

    foreach ($value in $Values) {
        if ($null -eq $value) {
            continue
        }

        $text = $value.ToString().Trim()
        if (-not $text) {
            continue
        }

        if ($text -match '^(LABEL|NAME|ID)\s*=\s*(.+)$') {
            return $Matches[2].Trim()
        }
    }

    return $null
}

function Get-StepIndexFromParameter {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    $text = $Value.ToString().Trim()
    if (-not $text) {
        return $null
    }

    if ($text -match '^(FROM|START|STEP|INDEX)\s*=\s*(\d+)$') {
        return [int]$Matches[2] - 1
    }

    if ($text -match '^(TO|END)\s*=\s*(\d+)$') {
        return [int]$Matches[2] - 1
    }

    if ($text -match '^\d+$') {
        return [int]$text - 1
    }

    return $null
}

function Invoke-IfAction {
    param($Connection, $Step)
    
    # 簡易的な条件判定（将来拡張）
    Write-Warning "[ScenarioEngine] IF action not fully implemented"
}

function Invoke-CallScriptAction {
    param($Connection, $Step)
    
    $scriptPath = $Step.Parameter1
    
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Script not found: $scriptPath"
        return
    }
    
    try {
        # スクリプト実行
        & $scriptPath -Connection $Connection | Out-Null
        
        Write-Host "[ScenarioEngine] Script executed: $scriptPath" -ForegroundColor Green
        
    } catch {
        Write-Error "[ScenarioEngine] Script execution failed: $_"
    }
}

# Export-ModuleMember -Function @(
#     'Read-ScenarioFile',
#     'Start-Scenario'
# )
