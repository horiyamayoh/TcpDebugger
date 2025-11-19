# MessageService.ps1
# ���b�Z�[�W�e���v���[�g�����ƃV�i���I���s�𓝍��Ǘ�

class MessageService {
    hidden [Logger]$_logger
    hidden [ConnectionService]$_connectionService
    hidden [hashtable]$_templateCache
    hidden [hashtable]$_customVariableHandlers

    MessageService([Logger]$logger, [ConnectionService]$connectionService) {
        $this._logger = $logger
        $this._connectionService = $connectionService
        $this._templateCache = @{}
        $this._customVariableHandlers = @{}
    }

    # �J�X�^���ϐ��n���h���[�̓o�^
    [void] RegisterCustomVariableHandler([string]$name, [scriptblock]$handler) {
        $key = $name.ToLowerInvariant()
        $this._customVariableHandlers[$key] = $handler
        $this._logger.LogInfo("Custom variable handler registered: $name")
    }

    # �J�X�^���ϐ��n���h���[�̍폜
    [void] UnregisterCustomVariableHandler([string]$name) {
        $key = $name.ToLowerInvariant()
        if ($this._customVariableHandlers.ContainsKey($key)) {
            $this._customVariableHandlers.Remove($key)
            $this._logger.LogInfo("Custom variable handler unregistered: $name")
        }
    }

    # �J�X�^���ϐ��n���h���[�̎��s
    [object] InvokeCustomVariableHandler([string]$identifier, [hashtable]$variables) {
        if ([string]::IsNullOrWhiteSpace($identifier)) {
            return $null
        }

        $handlerName = $identifier
        $argument = $null
        $separatorIndex = $identifier.IndexOf(':')
        if ($separatorIndex -ge 0) {
            $handlerName = $identifier.Substring(0, $separatorIndex)
            $argument = $identifier.Substring($separatorIndex + 1)
        }

        $key = $handlerName.ToLowerInvariant()
        if (-not $this._customVariableHandlers.ContainsKey($key)) {
            return $null
        }

        $context = [PSCustomObject]@{
            Name      = $handlerName
            Argument  = $argument
            RawValue  = $identifier
            Variables = $variables
        }

        try {
            return & $this._customVariableHandlers[$key] $context
        } catch {
            $this._logger.LogWarning("Custom variable handler '$handlerName' failed: $_")
            return $null
        }
    }

    # �e���v���[�g�̃��[�h�i�L���b�V���t���j
    [object] LoadTemplate([string]$filePath) {
        if ($this._templateCache.ContainsKey($filePath)) {
            $cached = $this._templateCache[$filePath]
            $fileInfo = Get-Item -LiteralPath $filePath -ErrorAction SilentlyContinue
            if ($fileInfo -and $fileInfo.LastWriteTime -eq $cached.LastModified) {
                return $cached.Data
            }
        }

        if (-not (Test-Path -LiteralPath $filePath)) {
            throw "Template file not found: $filePath"
        }

        $fileInfo = Get-Item -LiteralPath $filePath
        $content = Import-Csv -Path $filePath -Encoding UTF8

        $this._templateCache[$filePath] = @{
            Data = $content
            LastModified = $fileInfo.LastWriteTime
        }

        $this._logger.LogInfo("Template loaded and cached: $filePath")
        return $content
    }

    # �e���v���[�g�L���b�V���̃N���A
    [void] ClearTemplateCache() {
        $this._templateCache.Clear()
        $this._logger.LogInfo("Template cache cleared")
    }

    # �ϐ��̓W�J
    [string] ExpandVariables([string]$text, [hashtable]$variables) {
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $text
        }

        $result = $text
        $pattern = '\$\{([^}]+)\}'
        $matches = [regex]::Matches($result, $pattern)

        foreach ($match in $matches) {
            $varName = $match.Groups[1].Value
            $value = $null

            # �J�X�^���n���h���[�����s
            $customValue = $this.InvokeCustomVariableHandler($varName, $variables)
            if ($null -ne $customValue) {
                $value = $customValue
            }
            # �ʏ�̕ϐ������s
            elseif ($variables.ContainsKey($varName)) {
                $value = $variables[$varName]
            }
            # �g�ݍ��ݕϐ�
            else {
                $value = $this.ResolveBuiltInVariable($varName)
            }

            if ($null -ne $value) {
                $result = $result.Replace($match.Value, $value.ToString())
            }
        }

        return $result
    }

    # �g�ݍ��ݕϐ��̉���
    [object] ResolveBuiltInVariable([string]$name) {
        $result = switch ($name.ToLowerInvariant()) {
            'timestamp' { (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') }
            'timestamp_ms' { (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') }
            'unixtime' { [int]((Get-Date).ToUniversalTime() - (Get-Date '1970-01-01')).TotalSeconds }
            'guid' { [guid]::NewGuid().ToString() }
            'newline' { "`r`n" }
            'crlf' { "`r`n" }
            'lf' { "`n" }
            'tab' { "`t" }
            default { $null }
        }
        return $result
    }

    # ���b�Z�[�W���o�C�g�z��ɕϊ�
    [byte[]] ConvertMessageToBytes([string]$message, [string]$encoding) {
        if ([string]::IsNullOrWhiteSpace($message)) {
            return @()
        }

        $enc = switch ($encoding.ToLowerInvariant()) {
            'utf8' { [System.Text.Encoding]::UTF8 }
            'sjis' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
            'ascii' { [System.Text.Encoding]::ASCII }
            default { [System.Text.Encoding]::UTF8 }
        }

        return $enc.GetBytes($message)
    }

    # HEX��������o�C�g�z��ɕϊ�
    [byte[]] ConvertHexToBytes([string]$hexString) {
        $hex = $hexString -replace '\s+', ''
        if ($hex.Length % 2 -ne 0) {
            throw "Invalid hex string length: $($hex.Length)"
        }

        $bytes = New-Object byte[] ($hex.Length / 2)
        for ($i = 0; $i -lt $hex.Length; $i += 2) {
            $bytes[$i / 2] = [Convert]::ToByte($hex.Substring($i, 2), 16)
        }

        return $bytes
    }

    # �e���v���[�g���烁�b�Z�[�W�𐶐�
    [byte[]] ProcessTemplate([string]$templatePath, [hashtable]$variables, [string]$connectionId) {
        $template = $this.LoadTemplate($templatePath)
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        # �ڑ��̕ϐ��ƃ}�[�W
        $mergedVars = @{}
        foreach ($key in $conn.Variables.Keys) {
            $mergedVars[$key] = $conn.Variables[$key]
        }
        foreach ($key in $variables.Keys) {
            $mergedVars[$key] = $variables[$key]
        }

        # �e���v���[�g�����i�ŏ��̍s�݂̂��g�p�j
        if ($template -and $template.Count -gt 0) {
            $row = $template[0]
            $message = $row.Message
            if ($row.PSObject.Properties['Encoding']) {
                $encoding = $row.Encoding
            } else {
                $encoding = 'utf8'
            }

            $expanded = $this.ExpandVariables($message, $mergedVars)
            return $this.ConvertMessageToBytes($expanded, $encoding)
        }

        return @()
    }

    # �V�i���I�t�@�C���̓ǂݍ���
    [object[]] LoadScenario([string]$scenarioPath) {
        if (-not (Test-Path -LiteralPath $scenarioPath)) {
            throw "Scenario file not found: $scenarioPath"
        }

        $steps = Import-Csv -Path $scenarioPath -Encoding UTF8
        $this._logger.LogInfo("Scenario loaded: $scenarioPath ($($steps.Count) steps)")
        return $steps
    }


    # ViI̎si񓯊j
    [void] StartScenario([string]$connectionId, [string]$scenarioPath) {
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        $scenarioSteps = $this.LoadScenario($scenarioPath)
        $logger = $this._logger
        $messageService = $this
        $connectionService = $this._connectionService

        $scriptBlock = {
            param($connId, $steps, $svc, $log, $connSvc)

            $conn = $connSvc.GetConnection($connId)
            if (-not $conn) {
                $log.LogWarning("Connection not found during scenario execution", @{ ConnectionId = $connId })
                return
            }

            # シナリオ変数を接続変数から複製
            $variables = @{}
            foreach ($key in $conn.Variables.Keys) {
                $variables[$key] = $conn.Variables[$key]
            }

            $defaultEncoding = if ($variables.ContainsKey('DefaultEncoding')) { $variables['DefaultEncoding'] } else { 'UTF-8' }
            $lastRecvIndex = $conn.RecvBuffer.Count
            $lastReceived = $null

            for ($i = 0; $i -lt $steps.Count; $i++) {
                $step = $steps[$i]
                $action = if ($step.Action) { $step.Action.ToUpperInvariant() } else { '' }

                try {
                    switch ($action) {
                        'SEND' {
                            $encoding = if ($step.Parameter2) { $step.Parameter2 } else { $defaultEncoding }
                            $expanded = $svc.ExpandVariables([string]$step.Parameter1, $variables)
                            $bytes = $svc.ConvertMessageToBytes($expanded, $encoding)
                            [void]$conn.SendQueue.Add($bytes)
                            $log.LogInfo("Scenario SEND", @{ ConnectionId = $connId; Step = $step.Step; Length = $bytes.Length })
                        }
                        'SEND_HEX' {
                            $bytes = $svc.ConvertHexToBytes([string]$step.Parameter1)
                            [void]$conn.SendQueue.Add($bytes)
                            $log.LogInfo("Scenario SEND_HEX", @{ ConnectionId = $connId; Step = $step.Step; Length = $bytes.Length })
                        }
                        'SLEEP' {
                            $duration = 0
                            [int]::TryParse([string]$step.Parameter1, [ref]$duration) | Out-Null
                            if ($duration -gt 0) {
                                Start-Sleep -Milliseconds $duration
                            }
                        }
                        'WAIT_RECV' {
                            $timeoutMs = 5000
                            if ($step.Parameter1 -and [string]$step.Parameter1 -match 'TIMEOUT=([0-9]+)') {
                                $timeoutMs = [int]$Matches[1]
                            }

                            $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
                            $matched = $false
                            while ([DateTime]::UtcNow -lt $deadline) {
                                $conn = $connSvc.GetConnection($connId)
                                if (-not $conn) { break }

                                $currentCount = $conn.RecvBuffer.Count
                                if ($currentCount -gt $lastRecvIndex) {
                                    $lastReceived = $conn.RecvBuffer[$currentCount - 1]
                                    $lastRecvIndex = $currentCount

                                    $pattern = $null
                                    if ($step.Parameter2 -and [string]$step.Parameter2 -match 'PATTERN=(.+)') {
                                        $pattern = $Matches[1]
                                    }

                                    if ($pattern) {
                                        $recvText = try {
                                            [System.Text.Encoding]::GetEncoding($defaultEncoding).GetString($lastReceived.Data)
                                        } catch {
                                            [System.Text.Encoding]::UTF8.GetString($lastReceived.Data)
                                        }

                                        if ($recvText -notmatch $pattern) {
                                            continue
                                        }
                                    }

                                    $matched = $true
                                    break
                                }

                                Start-Sleep -Milliseconds 50
                            }

                            if (-not $matched) {
                                $log.LogWarning("WAIT_RECV timed out", @{ ConnectionId = $connId; Step = $step.Step })
                            }
                        }
                        'SAVE_RECV' {
                            $varName = $null
                            if ($step.Parameter1 -and [string]$step.Parameter1 -match 'VAR_NAME=(.+)') {
                                $varName = $Matches[1]
                            } elseif ($step.Parameter1) {
                                $varName = [string]$step.Parameter1
                            }

                            if (-not $varName) {
                                $log.LogWarning("SAVE_RECV requires VAR_NAME", @{ ConnectionId = $connId; Step = $step.Step })
                                continue
                            }

                            if (-not $lastReceived) {
                                $log.LogWarning("SAVE_RECV has no data to save", @{ ConnectionId = $connId; Step = $step.Step })
                                continue
                            }

                            $encoding = if ($step.Parameter2) { $step.Parameter2 } else { $defaultEncoding }
                            $text = try {
                                [System.Text.Encoding]::GetEncoding($encoding).GetString($lastReceived.Data)
                            } catch {
                                [System.Text.Encoding]::UTF8.GetString($lastReceived.Data)
                            }

                            $variables[$varName] = $text
                            $conn.Variables[$varName] = $text
                            $log.LogInfo("Saved received data to variable", @{ ConnectionId = $connId; Step = $step.Step; Variable = $varName })
                        }
                        default {
                            $log.LogWarning("Unsupported scenario action", @{ ConnectionId = $connId; Step = $step.Step; Action = $action })
                        }
                    }
                }
                catch {
                    $log.LogError("Scenario step failed", $_.Exception, @{ ConnectionId = $connId; Step = $step.Step; Action = $action })
                }
            }
        }

        $runspace = [powershell]::Create()
        $runspace.AddScript($scriptBlock).AddArgument($connectionId).AddArgument($scenarioSteps).AddArgument($messageService).AddArgument($logger).AddArgument($connectionService) | Out-Null
        $asyncResult = $runspace.BeginInvoke()

        Register-WaitForSingleObject -InputObject $asyncResult.AsyncWaitHandle -Action {
            param($state, $timedOut)
            try {
                $runspace.EndInvoke($asyncResult)
            } finally {
                $runspace.Dispose()
            }
        } | Out-Null

        $this._logger.LogInfo("Scenario started", @{ ConnectionId = $connectionId; Path = $scenarioPath; Steps = $scenarioSteps.Count })
    }

# =====================================================================
# �O���[�o���w���p�[�֐��i���݊����̂��߁j
# =====================================================================

function Get-MessageTemplateCache {
    <#
    .SYNOPSIS
    �d���e���v���[�g�t�@�C�����L���b�V���t���œǂݍ���
    
    .PARAMETER FilePath
    �e���v���[�g�t�@�C���̃p�X
    
    .PARAMETER ThrowOnMissing
    �t�@�C����������Ȃ��ꍇ�ɃG���[���X���[
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [switch]$ThrowOnMissing
    )
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        if ($ThrowOnMissing) {
            throw "Template file not found: $FilePath"
        }
        return @{}
    }
    
    # Shift-JIS��CSV�ǂݍ��݁i�d���t�@�C����Shift-JIS�`���j
    $sjisEncoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
    $rows = Import-Csv -Path $FilePath -Encoding $sjisEncoding
    
    if (-not $rows -or $rows.Count -eq 0) {
        return @{}
    }
    
    # �d���`���̏ꍇ�A���ׂĂ̍s����������HEX��������쐬
    $hexStream = ""
    foreach ($row in $rows) {
        # Row1, Row2, ... ��2��ڂ�HEX�l������
        $properties = $row.PSObject.Properties.Name
        if ($properties.Count -ge 2) {
            $hexValue = $properties[1]
            $hexStream += $row.$hexValue
        }
    }
    
    # DEFAULT�e���v���[�g�Ƃ��ĕԂ�
    $template = [PSCustomObject]@{
        Name = 'DEFAULT'
        Format = $hexStream
    }
    
    return @{
        'DEFAULT' = $template
    }
}

function ConvertTo-ByteArray {
    <#
    .SYNOPSIS
    文字列またはHEX文字列をバイト配列に変換

    .PARAMETER Data
    変換対象データ

    .PARAMETER Encoding
    エンコーディング（HEX, UTF-8, Shift_JIS, ASCII）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Data,

        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8"
    )

    if ([string]::IsNullOrWhiteSpace($Data)) {
        return @()
    }

    $normalizedEncoding = $Encoding.ToUpperInvariant() -replace '[_-]', ''

    if ($normalizedEncoding -eq 'HEX') {
        $hex = $Data -replace '\s+', ''
        if ($hex.Length % 2 -ne 0) {
            throw "Invalid hex string length: $($hex.Length)"
        }

        $bytes = New-Object byte[] ($hex.Length / 2)
        for ($i = 0; $i -lt $hex.Length; $i += 2) {
            $bytes[$i / 2] = [Convert]::ToByte($hex.Substring($i, 2), 16)
        }

        return $bytes
    }

    $enc = switch ($normalizedEncoding) {
        'UTF8' { [System.Text.Encoding]::UTF8 }
        'SHIFTJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'SJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'ASCII' { [System.Text.Encoding]::ASCII }
        default { [System.Text.Encoding]::UTF8 }
    }

    return $enc.GetBytes($Data)
}

function Get-MessageService {
    if ($Global:MessageService) {
        return $Global:MessageService
    }
    if ($Global:ServiceContainer) {
        return $Global:ServiceContainer.Resolve('MessageService')
    }
    throw "MessageService is not initialized."
}

function Start-Scenario {
    param(
        [Parameter(Mandatory=$true)][string]$ConnectionId,
        [Parameter(Mandatory=$true)][string]$ScenarioPath
    )

    if (-not (Test-Path -LiteralPath $ScenarioPath)) {
        throw "Scenario file not found: $ScenarioPath"
    }

    $service = Get-MessageService
    $service.StartScenario($ConnectionId, $ScenarioPath)
}

function ConvertFrom-ByteArray {
    <#
    .SYNOPSIS
    �o�C�g�z��𕶎���ɕϊ�
    
    .PARAMETER Data
    �o�C�g�z��
    
    .PARAMETER Encoding
    �G���R�[�f�B���O�iUTF-8, Shift_JIS, ASCII�j
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8"
    )
    
    if (-not $Data -or $Data.Length -eq 0) {
        return ""
    }
    
    $normalizedEncoding = $Encoding.ToUpperInvariant() -replace '[_-]', ''
    
    $enc = switch ($normalizedEncoding) {
        'UTF8' { [System.Text.Encoding]::UTF8 }
        'SHIFTJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'SJIS' { [System.Text.Encoding]::GetEncoding('Shift_JIS') }
        'ASCII' { [System.Text.Encoding]::ASCII }
        default { [System.Text.Encoding]::UTF8 }
    }
    
    return $enc.GetString($Data)
}

function Expand-MessageVariables {
    <#
    .SYNOPSIS
    ���b�Z�[�W�e���v���[�g���̕ϐ���W�J
    
    .PARAMETER Template
    �ϐ����܂ރe���v���[�g������
    
    .PARAMETER Variables
    �ϐ��̃n�b�V���e�[�u��
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Template,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Variables = @{}
    )
    
    if ($Global:MessageService) {
        return $Global:MessageService.ExpandVariables($Template, $Variables)
    }
    
    # �t�H�[���o�b�N: �ȈՎ���
    $result = $Template
    $pattern = '\$\{([^}]+)\}'
    $matches = [regex]::Matches($result, $pattern)
    
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value
        if ($Variables.ContainsKey($varName)) {
            $result = $result.Replace($match.Value, $Variables[$varName].ToString())
        }
    }
    
    return $result
}

