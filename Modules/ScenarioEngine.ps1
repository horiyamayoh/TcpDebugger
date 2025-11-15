# ScenarioEngine.ps1
# シナリオ実行エンジン - CSV形式シナリオの読み込みと実行

function Read-ScenarioFile {
    <#
    .SYNOPSIS

function Resolve-ScenarioPath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($TargetPath)) {
        return $TargetPath
    }

    $baseDirectory = if ($BasePath) {
        Split-Path -Path $BasePath -Parent
    } else {
        Get-Location
    }

    return Join-Path -Path $baseDirectory -ChildPath $TargetPath
}

function Get-StepFieldValue {
    param(
        [Parameter(Mandatory=$true)]
        $Step,

        [Parameter(Mandatory=$true)]
        [string[]]$PropertyNames
    )

    foreach ($name in $PropertyNames) {
        if ($Step.PSObject.Properties.Match($name)) {
            $value = $Step.$name
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                return [string]$value
            }
        }
    }

    return $null
}

function Test-ScenarioCondition {
    param(
        [string]$LeftValue,
        [string]$RightValue,
        [string]$Operator
    )

    $normalizedOperator = if ($null -ne $Operator) { [string]$Operator } else { '' }
    $normalizedOperator = $normalizedOperator.Trim()
    if ([string]::IsNullOrWhiteSpace($normalizedOperator)) {
        throw "IF action requires a comparison operator"
    }

    $normalizedOperator = $normalizedOperator.ToLowerInvariant()

    $left = if ($null -eq $LeftValue) { '' } else { [string]$LeftValue }
    $right = if ($null -eq $RightValue) { '' } else { [string]$RightValue }

    $leftNumber = 0
    $rightNumber = 0
    $leftIsNumber = [double]::TryParse($left, [ref]$leftNumber)
    $rightIsNumber = [double]::TryParse($right, [ref]$rightNumber)

    switch ($normalizedOperator) {
        '==' { return $left -eq $right }
        '=' { return $left -eq $right }
        '-eq' { return $left -eq $right }
        'eq' { return $left -eq $right }
        '!=' { return $left -ne $right }
        '-ne' { return $left -ne $right }
        'ne' { return $left -ne $right }
        '-like' { return $left -like $right }
        'like' { return $left -like $right }
        '-notlike' { return $left -notlike $right }
        'notlike' { return $left -notlike $right }
        '-match' { return $left -match $right }
        'match' { return $left -match $right }
        '-notmatch' { return $left -notmatch $right }
        'notmatch' { return $left -notmatch $right }
        '-gt' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -gt $rightNumber } else { return $left -gt $right } }
        '>' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -gt $rightNumber } else { return $left -gt $right } }
        '-ge' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -ge $rightNumber } else { return $left -ge $right } }
        '>=' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -ge $rightNumber } else { return $left -ge $right } }
        '-lt' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -lt $rightNumber } else { return $left -lt $right } }
        '<' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -lt $rightNumber } else { return $left -lt $right } }
        '-le' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -le $rightNumber } else { return $left -le $right } }
        '<=' { if ($leftIsNumber -and $rightIsNumber) { return $leftNumber -le $rightNumber } else { return $left -le $right } }
        default { throw "Unsupported operator for IF action: $Operator" }
    }
}

function Resolve-IfBranchAction {
    param(
        $Connection,
        [string]$ActionSpec,
        [hashtable]$StepIndexMap,
        $ScenarioSteps,
        [string]$ScenarioPath,
        [string]$ConnectionId,
        [int]$CurrentIndex
    )

    if ([string]::IsNullOrWhiteSpace($ActionSpec)) {
        return $null
    }

    $directives = $ActionSpec -split ';'
    $nextStepIndex = $null
    $terminate = $false

    foreach ($directive in $directives) {
        $instruction = $directive.Trim()
        if ([string]::IsNullOrWhiteSpace($instruction)) {
            continue
        }

        if ($instruction -match '^(STEP|GOTO):(.+)$') {
            $targetId = $Matches[2].Trim()
            if (-not $StepIndexMap.ContainsKey($targetId)) {
                throw "Step not found for IF branch: $targetId"
            }
            $nextStepIndex = $StepIndexMap[$targetId]
        } elseif ($instruction -match '^(INDEX):(\d+)$') {
            $nextStepIndex = [int]$Matches[2]
        } elseif ($instruction -match '^(CALL|SCENARIO):(.+)$') {
            $scenarioPath = $Matches[2].Trim()
            $resolvedPath = Resolve-ScenarioPath -BasePath $ScenarioPath -TargetPath $scenarioPath
            if (-not (Test-Path $resolvedPath)) {
                throw "Scenario file not found for IF branch: $resolvedPath"
            }

            Write-Host "[ScenarioEngine] IF branch calling scenario: $resolvedPath" -ForegroundColor DarkCyan
            $subSteps = Read-ScenarioFile -FilePath $resolvedPath
            Invoke-ScenarioSteps -Connection $Connection -ScenarioSteps $subSteps -ScenarioPath $resolvedPath -ConnectionId $ConnectionId
        } elseif ($instruction -match '^(END|STOP|TERMINATE)$') {
            $terminate = $true
        } elseif ($instruction -match '^(NEXT)$') {
            $nextStepIndex = $CurrentIndex + 1
        } elseif ($StepIndexMap.ContainsKey($instruction)) {
            $nextStepIndex = $StepIndexMap[$instruction]
        } else {
            throw "Unsupported IF branch directive: $instruction"
        }
    }

    if ($terminate -or ($null -ne $nextStepIndex)) {
        $result = @{}
        if ($null -ne $nextStepIndex) {
            $result['NextStepIndex'] = [int]$nextStepIndex
        }
        if ($terminate) {
            $result['Terminate'] = $true
        }
        return [pscustomobject]$result
    }

    return $null
}









function Invoke-ScenarioSteps {
    param(
        [Parameter(Mandatory=$true)]
        $Connection,

        [Parameter(Mandatory=$true)]
        $ScenarioSteps,

        [string]$ScenarioPath,

        [string]$ConnectionId
    )

    if (-not $ScenarioSteps) {
        return
    }

    $stepIndexMap = @{}
    for ($i = 0; $i -lt $ScenarioSteps.Count; $i++) {
        $stepId = $ScenarioSteps[$i].Step
        if (-not [string]::IsNullOrWhiteSpace([string]$stepId)) {
            if ($stepIndexMap.ContainsKey($stepId)) {
                Write-Warning "Duplicate step identifier detected: $stepId"
            }
            $stepIndexMap[$stepId] = $i
        }
    }

    $stepIndex = 0
    $totalSteps = $ScenarioSteps.Count

    while ($stepIndex -lt $totalSteps) {
        if ($Connection.CancellationSource -and $Connection.CancellationSource.Token.IsCancellationRequested) {
            Write-Host "[ScenarioEngine] Scenario cancelled" -ForegroundColor Yellow
            break
        }

        $step = $ScenarioSteps[$stepIndex]
        $actionName = if ($step.Action) { $step.Action.ToUpperInvariant() } else { '' }
        $displayStep = if ($step.Step) { $step.Step } else { $stepIndex + 1 }

        Write-Host "[ScenarioEngine] Step $($stepIndex + 1)/$totalSteps [$displayStep] : $actionName" -ForegroundColor Cyan

        $actionResult = $null
        $shouldBreak = $false

        if ([string]::IsNullOrWhiteSpace($actionName)) {
            Write-Warning "Step $displayStep has no action defined. Skipping."
            $stepIndex++
            continue
        }

        switch ($actionName) {
            'SEND' {
                Invoke-SendAction -Connection $Connection -Step $step
            }
            'SEND_HEX' {
                Invoke-SendHexAction -Connection $Connection -Step $step
            }
            'SEND_FILE' {
                Invoke-SendFileAction -Connection $Connection -Step $step
            }
            'WAIT_RECV' {
                Invoke-WaitRecvAction -Connection $Connection -Step $step
            }
            'SAVE_RECV' {
                Invoke-SaveRecvAction -Connection $Connection -Step $step
            }
            'SLEEP' {
                Invoke-SleepAction -Connection $Connection -Step $step
            }
            'SET_VAR' {
                Invoke-SetVarAction -Connection $Connection -Step $step
            }
            'IF' {
                $actionResult = Invoke-IfAction `
                    -Connection $Connection `
                    -Step $step `
                    -StepIndexMap $stepIndexMap `
                    -CurrentIndex $stepIndex `
                    -ScenarioSteps $ScenarioSteps `
                    -ScenarioPath $ScenarioPath `
                    -ConnectionId $ConnectionId
            }
            'GOTO' {
                $actionResult = Invoke-GotoAction -Step $step -StepIndexMap $stepIndexMap
            }
            'LOOP' {
                Write-Warning "LOOP action not yet implemented"
            }
            'CALL_SCRIPT' {
                Invoke-CallScriptAction -Connection $Connection -Step $step
            }
            'DISCONNECT' {
                if ($ConnectionId) {
                    Stop-Connection -ConnectionId $ConnectionId
                } elseif ($Connection.Id) {
                    Stop-Connection -ConnectionId $Connection.Id
                }
                $shouldBreak = $true
            }
            'RECONNECT' {
                if ($ConnectionId) {
                    Stop-Connection -ConnectionId $ConnectionId
                    Start-Sleep -Seconds 1
                    Start-Connection -ConnectionId $ConnectionId
                } elseif ($Connection.Id) {
                    Stop-Connection -ConnectionId $Connection.Id
                    Start-Sleep -Seconds 1
                    Start-Connection -ConnectionId $Connection.Id
                }
            }
            default {
                if (-not [string]::IsNullOrWhiteSpace($actionName)) {
                    Write-Warning "Unknown action: $actionName"
                }
            }
        }

        if ($shouldBreak) {
            break
        }

        $terminate = $false
        $nextStepIndex = $null

        if ($null -ne $actionResult) {
            if ($actionResult -is [int]) {
                $nextStepIndex = [int]$actionResult
            } elseif ($actionResult -is [System.Collections.IDictionary]) {
                if ($actionResult.Contains('Terminate') -and $actionResult['Terminate']) {
                    $terminate = $true
                }
                if ($actionResult.Contains('NextStepIndex')) {
                    $nextStepIndex = [int]$actionResult['NextStepIndex']
                } elseif ($actionResult.Contains('NextStepId')) {
                    $targetId = [string]$actionResult['NextStepId']
                    if (-not $stepIndexMap.ContainsKey($targetId)) {
                        throw "Step not found: $targetId"
                    }
                    $nextStepIndex = $stepIndexMap[$targetId]
                }
            } else {
                $props = $actionResult.PSObject.Properties
                if ($props['Terminate'] -and $props['Terminate'].Value) {
                    $terminate = $true
                }
                if ($props['NextStepIndex']) {
                    $nextStepIndex = [int]$props['NextStepIndex'].Value
                } elseif ($props['NextStepId']) {
                    $targetId = [string]$props['NextStepId'].Value
                    if (-not $stepIndexMap.ContainsKey($targetId)) {
                        throw "Step not found: $targetId"
                    }
                    $nextStepIndex = $stepIndexMap[$targetId]
                }
            }
        }

        if ($terminate) {
            break
        }

        if ($null -ne $nextStepIndex) {
            $stepIndex = $nextStepIndex
            continue
        }

        $stepIndex++
    }
}



                    }
                    "WAIT_RECV" {
                        Invoke-WaitRecvAction -Connection $conn -Step $step
                    }
                    "SAVE_RECV" {
                        Invoke-SaveRecvAction -Connection $conn -Step $step
                    }
                    "SLEEP" {
                        Invoke-SleepAction -Connection $conn -Step $step
                    }
                    "SET_VAR" {
                        Invoke-SetVarAction -Connection $conn -Step $step
                    }
                    "IF" {
                        Invoke-IfAction -Connection $conn -Step $step
                    }
                    "LOOP" {
                        # TODO: ループ処理実装
                        Write-Warning "LOOP action not yet implemented"
                    }
                    "CALL_SCRIPT" {
                        Invoke-CallScriptAction -Connection $conn -Step $step
                    }
                    "DISCONNECT" {
                        Stop-Connection -ConnectionId $connId
                        break
                    }
                    "RECONNECT" {
                        Stop-Connection -ConnectionId $connId
                        Start-Sleep -Seconds 1
                        Start-Connection -ConnectionId $connId
                    }
                    default {
                        Write-Warning "Unknown action: $($step.Action)"
                    }
                }
            }
            
            Write-Host "[ScenarioEngine] Scenario completed successfully" -ForegroundColor Green
            
        } catch {
            Write-Error "[ScenarioEngine] Scenario execution error: $_"
        }
    }
    
    # スレッド開始
    $thread = New-Object System.Threading.Thread([System.Threading.ThreadStart]{
        & $scriptBlock -connId $ConnectionId -scenarioSteps $steps
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
    
    $expandedValue = Expand-MessageVariables -Template $varValue -Variables $Connection.Variables
    
    $Connection.Variables[$varName] = $expandedValue
    
    Write-Host "[ScenarioEngine] Set variable '$varName' = '$expandedValue'" -ForegroundColor Green
}

function Invoke-GotoAction {
    param(
        $Step,
        [hashtable]$StepIndexMap
    )

    $targetId = Get-StepFieldValue -Step $Step -PropertyNames @('Target', 'Parameter1')

    if ([string]::IsNullOrWhiteSpace($targetId)) {
        throw "GOTO action requires Parameter1 (target step identifier)"
    }

    if (-not $StepIndexMap.ContainsKey($targetId)) {
        throw "GOTO target step not found: $targetId"
    }

    Write-Host "[ScenarioEngine] Jumping to step '$targetId'" -ForegroundColor DarkCyan

    return [pscustomobject]@{
        NextStepIndex = [int]$StepIndexMap[$targetId]
    }
}

function Invoke-IfAction {
    param(
        $Connection,
        $Step,
        [hashtable]$StepIndexMap,
        [int]$CurrentIndex,
        $ScenarioSteps,
        [string]$ScenarioPath,
        [string]$ConnectionId
    )

    $leftExpression = Get-StepFieldValue -Step $Step -PropertyNames @('Left', 'Parameter1')
    $operator = Get-StepFieldValue -Step $Step -PropertyNames @('Operator', 'Parameter2')
    $rightExpression = Get-StepFieldValue -Step $Step -PropertyNames @('Right', 'Parameter3')

    if ([string]::IsNullOrWhiteSpace($leftExpression)) {
        throw "IF action requires Parameter1 (left value)"
    }

    if ([string]::IsNullOrWhiteSpace($operator)) {
        throw "IF action requires Parameter2 (comparison operator)"
    }

    $leftValue = Expand-MessageVariables -Template $leftExpression -Variables $Connection.Variables
    $rightValue = Expand-MessageVariables -Template $rightExpression -Variables $Connection.Variables

    $conditionResult = Test-ScenarioCondition -LeftValue $leftValue -RightValue $rightValue -Operator $operator

    $branchLabel = if ($conditionResult) { 'TRUE' } else { 'FALSE' }
    Write-Host "[ScenarioEngine] IF condition ($leftValue $operator $rightValue) => $branchLabel" -ForegroundColor DarkCyan

    $branchAction = if ($conditionResult) {
        Get-StepFieldValue -Step $Step -PropertyNames @('OnTrue', 'TrueAction', 'Parameter4')
    } else {
        Get-StepFieldValue -Step $Step -PropertyNames @('OnFalse', 'FalseAction', 'Parameter5')
    }

    if ([string]::IsNullOrWhiteSpace($branchAction)) {
        Write-Host "[ScenarioEngine] IF branch '$branchLabel' has no action. Continuing." -ForegroundColor DarkGray
        return $null
    }

    return Resolve-IfBranchAction `
        -Connection $Connection `
        -ActionSpec $branchAction `
        -StepIndexMap $StepIndexMap `
        -ScenarioSteps $ScenarioSteps `
        -ScenarioPath $ScenarioPath `
        -ConnectionId $ConnectionId `
        -CurrentIndex $CurrentIndex
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
