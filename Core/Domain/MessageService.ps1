# MessageService.ps1
# メッセージテンプレート処理とシナリオ実行を統合管理

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

    # カスタム変数ハンドラーの登録
    [void] RegisterCustomVariableHandler([string]$name, [scriptblock]$handler) {
        $key = $name.ToLowerInvariant()
        $this._customVariableHandlers[$key] = $handler
        $this._logger.LogInfo("Custom variable handler registered: $name")
    }

    # カスタム変数ハンドラーの削除
    [void] UnregisterCustomVariableHandler([string]$name) {
        $key = $name.ToLowerInvariant()
        if ($this._customVariableHandlers.ContainsKey($key)) {
            $this._customVariableHandlers.Remove($key)
            $this._logger.LogInfo("Custom variable handler unregistered: $name")
        }
    }

    # カスタム変数ハンドラーの実行
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

    # テンプレートのロード（キャッシュ付き）
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

    # テンプレートキャッシュのクリア
    [void] ClearTemplateCache() {
        $this._templateCache.Clear()
        $this._logger.LogInfo("Template cache cleared")
    }

    # 変数の展開
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

            # カスタムハンドラーを試行
            $customValue = $this.InvokeCustomVariableHandler($varName, $variables)
            if ($null -ne $customValue) {
                $value = $customValue
            }
            # 通常の変数を試行
            elseif ($variables.ContainsKey($varName)) {
                $value = $variables[$varName]
            }
            # 組み込み変数
            else {
                $value = $this.ResolveBuiltInVariable($varName)
            }

            if ($null -ne $value) {
                $result = $result.Replace($match.Value, $value.ToString())
            }
        }

        return $result
    }

    # 組み込み変数の解決
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

    # メッセージをバイト配列に変換
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

    # HEX文字列をバイト配列に変換
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

    # テンプレートからメッセージを生成
    [byte[]] ProcessTemplate([string]$templatePath, [hashtable]$variables, [string]$connectionId) {
        $template = $this.LoadTemplate($templatePath)
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        # 接続の変数とマージ
        $mergedVars = @{}
        foreach ($key in $conn.Variables.Keys) {
            $mergedVars[$key] = $conn.Variables[$key]
        }
        foreach ($key in $variables.Keys) {
            $mergedVars[$key] = $variables[$key]
        }

        # テンプレート処理（最初の行のみを使用）
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

    # シナリオファイルの読み込み
    [object[]] LoadScenario([string]$scenarioPath) {
        if (-not (Test-Path -LiteralPath $scenarioPath)) {
            throw "Scenario file not found: $scenarioPath"
        }

        $steps = Import-Csv -Path $scenarioPath -Encoding UTF8
        $this._logger.LogInfo("Scenario loaded: $scenarioPath ($($steps.Count) steps)")
        return $steps
    }

    # シナリオの実行（非同期）
    [void] StartScenario([string]$connectionId, [string]$scenarioPath) {
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        $scenarioSteps = $this.LoadScenario($scenarioPath)
        $logger = $this._logger
        $messageService = $this

        $scriptBlock = {
            param($connId, $steps, $svc, $log)

            try {
                for ($i = 0; $i -lt $steps.Count; $i++) {
                    $step = $steps[$i]
                    $log.LogInfo("Scenario step $($i+1)/$($steps.Count): $($step.Action)")

                    # ここでシナリオステップを実行
                    # （詳細実装は後続で追加）
                }
            } catch {
                $log.LogError("Scenario execution failed", $_)
            }
        }

        $runspace = [powershell]::Create()
        $runspace.AddScript($scriptBlock).AddArgument($connectionId).AddArgument($scenarioSteps).AddArgument($messageService).AddArgument($logger) | Out-Null
        $null = $runspace.BeginInvoke()

        $this._logger.LogInfo("Scenario started: $scenarioPath for connection: $connectionId")
    }

    # テンプレートからメッセージを送信
    [void] SendTemplate([string]$connectionId, [string]$templatePath, [hashtable]$variables) {
        $bytes = $this.ProcessTemplate($templatePath, $variables, $connectionId)
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        if ($conn.Stream -and $conn.Stream.CanWrite) {
            $conn.Stream.Write($bytes, 0, $bytes.Length)
            $conn.Stream.Flush()
            $this._logger.LogInfo("Template sent: $templatePath to $connectionId ($($bytes.Length) bytes)")
        } else {
            throw "Connection stream is not writable: $connectionId"
        }
    }

    # バイトデータを送信
    [void] SendBytes([string]$connectionId, [byte[]]$data) {
        $conn = $this._connectionService.GetConnection($connectionId)
        if (-not $conn) {
            throw "Connection not found: $connectionId"
        }

        if ($conn.Stream -and $conn.Stream.CanWrite) {
            $conn.Stream.Write($data, 0, $data.Length)
            $conn.Stream.Flush()
            $this._logger.LogInfo("Bytes sent to $connectionId ($($data.Length) bytes)")
        } else {
            throw "Connection stream is not writable: $connectionId"
        }
    }

    # HEX文字列を送信
    [void] SendHex([string]$connectionId, [string]$hexString) {
        $bytes = $this.ConvertHexToBytes($hexString)
        $this.SendBytes($connectionId, $bytes)
    }

    # テキストメッセージを送信
    [void] SendText([string]$connectionId, [string]$text, [string]$encoding) {
        $bytes = $this.ConvertMessageToBytes($text, $encoding)
        $this.SendBytes($connectionId, $bytes)
    }
}
