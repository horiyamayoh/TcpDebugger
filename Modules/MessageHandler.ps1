# MessageHandler.ps1
# [DEPRECATED] このモジュールは非推奨です。MessageServiceを直接使用してください。

# メッセージテンプレート - エンコード/デコード/変数処理

if (-not $script:MessageTemplateCache) {
    $script:MessageTemplateCache = @{}
}

if (-not $script:CustomVariableHandlers) {
    $script:CustomVariableHandlers = @{}
}

function Register-CustomVariableHandler {
    <#
    .SYNOPSIS
    カスタム変数ハンドラーを登録
    
    .DESCRIPTION
    [非推奨] この関数は後方互換性のために残されています。
    新しいコードでは $Global:MessageService.RegisterCustomVariableHandler() を使用してください。
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]$Handler
    )

    if ($Global:MessageService) {
        $Global:MessageService.RegisterCustomVariableHandler($Name, $Handler)
    } else {
        $key = $Name.ToLowerInvariant()
        $script:CustomVariableHandlers[$key] = $Handler
    }
}

function Unregister-CustomVariableHandler {
    <#
    .SYNOPSIS
    カスタム変数ハンドラーを削除
    
    .DESCRIPTION
    [非推奨] この関数は後方互換性のために残されています。
    新しいコードでは $Global:MessageService.UnregisterCustomVariableHandler() を使用してください。
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    if ($Global:MessageService) {
        $Global:MessageService.UnregisterCustomVariableHandler($Name)
    } else {
        $key = $Name.ToLowerInvariant()
        if ($script:CustomVariableHandlers.ContainsKey($key)) {
            $script:CustomVariableHandlers.Remove($key)
        }
    }
}

function Clear-CustomVariableHandlers {
    <#
    .SYNOPSIS
    全てのカスタムハンドラーをクリア
    
    .DESCRIPTION
    [非推奨] この関数は後方互換性のために残されています。
    #>
    $script:CustomVariableHandlers.Clear()
}

function Invoke-CustomVariableHandler {
    <#
    .SYNOPSIS
    カスタム変数ハンドラーを実行
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identifier,

        [Parameter(Mandatory=$true)]
        [hashtable]$Variables
    )

    if (-not $Identifier) {
        return $null
    }

    $handlerName = $Identifier
    $argument = $null
    $separatorIndex = $Identifier.IndexOf(':')
    if ($separatorIndex -ge 0) {
        $handlerName = $Identifier.Substring(0, $separatorIndex)
        $argument = $Identifier.Substring($separatorIndex + 1)
    }

    $key = $handlerName.ToLowerInvariant()
    if (-not $script:CustomVariableHandlers.ContainsKey($key)) {
        return $null
    }

    $context = [PSCustomObject]@{
        Name      = $handlerName
        Argument  = $argument
        RawValue  = $Identifier
        Variables = $Variables
    }

    try {
        return & $script:CustomVariableHandlers[$key] $context
    } catch {
        Write-Warning "Custom variable handler '$handlerName' failed: $_"
        return $null
    }
}

function Get-MessageTemplateCache {
    <#
    .SYNOPSIS
    テンプレートファイルのキャッシュデータを読み込み（キャッシュ付き）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter()]
        [switch]$ThrowOnMissing
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        if ($ThrowOnMissing) {
            throw "Template file not found: $FilePath"
        }
        return @{}
    }

    $resolvedPath = (Resolve-Path -LiteralPath $FilePath).Path
    $fileInfo = Get-Item -LiteralPath $resolvedPath
    $lastWrite = $fileInfo.LastWriteTimeUtc

    if ($script:MessageTemplateCache.ContainsKey($resolvedPath)) {
        $entry = $script:MessageTemplateCache[$resolvedPath]
        if ($entry.LastWriteTimeUtc -eq $lastWrite) {
            return $entry.Templates
        }
    }

    $templates = @{}
    
    # Shift-JISでCSVファイルを読み込み
    $sjisEncoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
    $csvLines = [System.IO.File]::ReadAllLines($resolvedPath, $sjisEncoding)
    
    # 新形式の電文定義: 2列CSV（1列目=コメント、2列目=16進数データ）
    $isNewFormat = $false
    if ($csvLines.Count -gt 0) {
        # ヘッダーの有無を確認（旧形式はTemplateName,MessageFormat,Encoding）
        $firstLine = $csvLines[0]
        if ($firstLine -notmatch '^TemplateName,') {
            $isNewFormat = $true
        }
    }
    
    if ($isNewFormat) {
        # 新形式: 全行の2列目を連結して1つの16進数ストリームを作成
        $hexStream = ""
        $lineNumber = 0
        
        foreach ($line in $csvLines) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            
            # カンマで分割
            $parts = $line.Split(',')
            if ($parts.Count -lt 2) {
                throw "Line ${lineNumber}: CSV must have 2 columns (comment, hexdata)"
            }
            
            $hexData = $parts[1].Trim()
            
            if ([string]::IsNullOrWhiteSpace($hexData)) {
                continue
            }
            
            # 16進数文字のみかチェック
            if ($hexData -notmatch '^[0-9A-Fa-f]+$') {
                throw "Line ${lineNumber}: Invalid hex characters found in '${hexData}'"
            }
            
            $hexStream += $hexData
        }
        
        # 奇数長チェック
        if ($hexStream.Length % 2 -ne 0) {
            throw "Total hex stream length is odd (${hexStream.Length} characters). Must be even."
        }
        
        # デフォルトテンプレート名で格納
        $templates['DEFAULT'] = [PSCustomObject]@{
            Name     = 'DEFAULT'
            Format   = $hexStream
            Encoding = 'HEX'
        }
        
    } else {
        # 旧形式: UTF-8でCSVを読み込み
        $csv = Import-Csv -Path $resolvedPath -Encoding UTF8
        foreach ($row in $csv) {
            $templates[$row.TemplateName] = [PSCustomObject]@{
                Name     = $row.TemplateName
                Format   = $row.MessageFormat
                Encoding = $row.Encoding
            }
        }
    }

    $script:MessageTemplateCache[$resolvedPath] = @{
        LastWriteTimeUtc = $lastWrite
        Templates        = $templates
    }

    return $templates
}

function Get-InstanceMessageTemplates {
    <#
    .SYNOPSIS
    インスタンスのテンプレートを取得（インスタンスCache付き）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Variables
    )

    if (-not $Variables) {
        return @{}
    }

    if ($Variables.ContainsKey('__MessageTemplates')) {
        return $Variables['__MessageTemplates']
    }

    if (-not $Variables.ContainsKey('InstancePath')) {
        $Variables['__MessageTemplates'] = @{}
        return $Variables['__MessageTemplates']
    }

    $instancePath = $Variables['InstancePath']
    if (-not $instancePath) {
        $Variables['__MessageTemplates'] = @{}
        return $Variables['__MessageTemplates']
    }

    $templateFile = Join-Path $instancePath "templates\messages.csv"
    $templates = Get-MessageTemplateCache -FilePath $templateFile
    $Variables['__MessageTemplates'] = $templates
    return $templates
}


function ConvertTo-ByteArray {
    <#
    .SYNOPSIS
    文字列データをバイト配列に変換
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Data,

        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8",

        [Parameter(Mandatory=$false)]
        [switch]$IsHex
    )

    $encodingName = if ($Encoding) { $Encoding } else { "UTF-8" }
    $normalizedEncoding = $encodingName.ToUpperInvariant()
    $useHex = $IsHex -or ($normalizedEncoding -eq "HEX")

    if ($useHex) {
        $cleanHex = $Data -replace '[\s-]', '' -replace '0x', ''
        if ($cleanHex.Length % 2 -ne 0) {
            throw "Hex string must have an even number of characters: $Data"
        }

        $bytes = @()
        for ($i = 0; $i -lt $cleanHex.Length; $i += 2) {
            $hexByte = $cleanHex.Substring($i, 2)
            $bytes += [Convert]::ToByte($hexByte, 16)
        }

        return [byte[]]$bytes

    } elseif ($normalizedEncoding -eq "BASE64") {
        return [System.Convert]::FromBase64String($Data)

    } else {
        switch ($normalizedEncoding) {
            "ASCII" {
                return [System.Text.Encoding]::ASCII.GetBytes($Data)
            }
            "UTF-8" {
                return [System.Text.Encoding]::UTF8.GetBytes($Data)
            }
            "UTF8" {
                return [System.Text.Encoding]::UTF8.GetBytes($Data)
            }
            "SHIFT-JIS" {
                $sjis = [System.Text.Encoding]::GetEncoding("Shift_JIS")
                return $sjis.GetBytes($Data)
            }
            "SHIFT_JIS" {
                $sjis = [System.Text.Encoding]::GetEncoding("Shift_JIS")
                return $sjis.GetBytes($Data)
            }
            default {
                try {
                    $encodingInstance = [System.Text.Encoding]::GetEncoding($encodingName)
                    return $encodingInstance.GetBytes($Data)
                } catch {
                    return [System.Text.Encoding]::UTF8.GetBytes($Data)
                }
            }
        }
    }
}


function ConvertFrom-ByteArray {
    <#
    .SYNOPSIS
    バイト配列を文字列データに変換
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,

        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8",

        [Parameter(Mandatory=$false)]
        [switch]$AsHex
    )

    $encodingName = if ($Encoding) { $Encoding } else { "UTF-8" }
    $normalizedEncoding = $encodingName.ToUpperInvariant()
    $outputHex = $AsHex -or ($normalizedEncoding -eq "HEX")

    if ($outputHex) {
        $hexString = ($Data | ForEach-Object { $_.ToString("X2") }) -join ' '
        return $hexString

    } elseif ($normalizedEncoding -eq "BASE64") {
        return [System.Convert]::ToBase64String($Data)

    } else {
        switch ($normalizedEncoding) {
            "ASCII" {
                return [System.Text.Encoding]::ASCII.GetString($Data)
            }
            "UTF-8" {
                return [System.Text.Encoding]::UTF8.GetString($Data)
            }
            "UTF8" {
                return [System.Text.Encoding]::UTF8.GetString($Data)
            }
            "SHIFT-JIS" {
                $sjis = [System.Text.Encoding]::GetEncoding("Shift_JIS")
                return $sjis.GetString($Data)
            }
            "SHIFT_JIS" {
                $sjis = [System.Text.Encoding]::GetEncoding("Shift_JIS")
                return $sjis.GetString($Data)
            }
            default {
                try {
                    $encodingInstance = [System.Text.Encoding]::GetEncoding($encodingName)
                    return $encodingInstance.GetString($Data)
                } catch {
                    return [System.Text.Encoding]::UTF8.GetString($Data)
                }
            }
        }
    }
}


function Expand-MessageVariables {
    <#
    .SYNOPSIS
    メッセージ内の変数を展開
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Template,

        [Parameter(Mandatory=$false)]
        [hashtable]$Variables = @{}
    )

    if (-not $Variables) {
        $Variables = @{}
    }

    $result = if ($Template) { $Template } else { "" }
    $pattern = '\$\{([^}]+)\}'
    $maxIterations = 10
    $iteration = 0

    while ($iteration -lt $maxIterations) {
        $matches = [regex]::Matches($result, $pattern)
        if ($matches.Count -eq 0) {
            break
        }

        $replaced = $false
        $sortedMatches = @($matches) | Sort-Object -Property Index -Descending
        foreach ($match in $sortedMatches) {
            $placeholder = $match.Groups[1].Value
            $replacement = Resolve-VariablePlaceholder -Placeholder $placeholder -Variables $Variables
            if ($null -eq $replacement) {
                $replacement = ""
            }
            $replacementText = [string]$replacement
            $result = $result.Remove($match.Index, $match.Length).Insert($match.Index, $replacementText)
            $replaced = $true
        }

        if (-not $replaced) {
            break
        }

        $iteration++
    }

    if ([regex]::IsMatch($result, $pattern)) {
        Write-Warning "Variable expansion did not complete within $maxIterations iterations: $result"
    }

    return $result
}

function Resolve-VariablePlaceholder {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Placeholder,

        [Parameter(Mandatory=$true)]
        [hashtable]$Variables
    )

    if ([string]::IsNullOrWhiteSpace($Placeholder)) {
        return ""
    }

    $upperName = $Placeholder.ToUpperInvariant()

    if ($upperName -eq "TIMESTAMP") {
        return Get-Date -Format "yyyyMMddHHmmss"
    }

    if ($Placeholder -match '^(?i)DATETIME:(.+)$') {
        $format = $Matches[1]
        if ($format) {
            return Get-Date -Format $format
        }
        return Get-Date
    }

    if ($Placeholder -match '^(?i)RANDOM:(.+)$') {
        $rangeText = $Matches[1]
        $parts = $rangeText.Split('-', 2)
        if ($parts.Count -eq 2) {
            $min = [int]($parts[0].Trim())
            $max = [int]($parts[1].Trim())
            if ($max -lt $min) {
                $temp = $min
                $min = $max
                $max = $temp
            }
            if ($max -eq $min) {
                return $min
            }
            return Get-Random -Minimum $min -Maximum ($max + 1)
        }
        return Get-Random
    }

    if ($Placeholder -match '^(?i)SEQ:(.+)$') {
        $seqName = $Matches[1].Trim()
        $seqKey = "SEQ_$seqName"
        if ($Variables.ContainsKey($seqKey)) {
            $Variables[$seqKey] = [int]$Variables[$seqKey] + 1
        } else {
            $Variables[$seqKey] = 1
        }
        return $Variables[$seqKey]
    }

    if ($Placeholder -match '^(?i)HEX:(.+)$') {
        return $Matches[1]
    }

    if ($Placeholder -match '^(?i)CALC:(.+)$') {
        $expression = $Matches[1]
        try {
            $scriptBlock = [scriptblock]::Create($expression)
            return $scriptBlock.Invoke()
        } catch {
            Write-Warning "Failed to evaluate expression: $expression"
            return ""
        }
    }

    if ($upperName -eq "HOSTNAME") {
        return [System.Environment]::MachineName
    }

    if ($upperName -eq "USERNAME") {
        return [System.Environment]::UserName
    }

    if ($Placeholder -match '^(?i)ENV:(.+)$') {
        $envName = $Matches[1].Trim()
        if ($envName) {
            return [System.Environment]::GetEnvironmentVariable($envName)
        }
        return ""
    }

    if ($Placeholder -match '^(?i)VAR:(.+)$') {
        $varKey = $Matches[1].Trim()
        if ($Variables.ContainsKey($varKey)) {
            return $Variables[$varKey]
        }
    }

    if ($Placeholder -match '^(?i)CUSTOM:(.+)$') {
        $customId = $Matches[1].Trim()
        $customValue = Invoke-CustomVariableHandler -Identifier $customId -Variables $Variables
        if ($null -ne $customValue) {
            return $customValue
        }
        $customKey = "CUSTOM:$customId"
        if ($Variables.ContainsKey($customKey)) {
            return $Variables[$customKey]
        }
    }

    if ($Variables.ContainsKey($Placeholder)) {
        return $Variables[$Placeholder]
    }

    $templates = Get-InstanceMessageTemplates -Variables $Variables
    if ($templates -and $templates.ContainsKey($Placeholder)) {
        $templateDef = $templates[$Placeholder]
        if ($templateDef -and $templateDef.Format) {
            return $templateDef.Format
        }
    }

    Write-Warning "Variable not found: $Placeholder"
    return ""
}


function Get-MessageSummary {
    <#
    .SYNOPSIS
    メッセージの概要を生成（表示用）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxLength = 50
    )
    
    try {
        # まずUTF-8でデコードを試みる
        $text = [System.Text.Encoding]::UTF8.GetString($Data)
        
        # 制御文字を置換
        $text = $text -replace '[\x00-\x1F\x7F]', '.'
        
        # 長さを制限
        if ($text.Length -gt $MaxLength) {
            $text = $text.Substring(0, $MaxLength) + "..."
        }
        
        return $text
        
    } catch {
        # デコードに失敗したらHEX表示
        $hexString = ($Data[0..[Math]::Min($Data.Length-1, 16)] | ForEach-Object { $_.ToString("X2") }) -join ' '
        if ($Data.Length -gt 16) {
            $hexString += "..."
        }
        return $hexString
    }
}

function Read-TemplateFile {
    <#
    .SYNOPSIS
    テンプレートファイルを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    return Get-MessageTemplateCache -FilePath $FilePath -ThrowOnMissing
}


function Format-MessageForDisplay {
    <#
    .SYNOPSIS
    表示用にメッセージをフォーマット
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$false)]
        [string]$Direction = "SEND",  # SEND/RECV
        
        [Parameter(Mandatory=$false)]
        [datetime]$Timestamp
    )
    
    if (-not $Timestamp) {
        $Timestamp = Get-Date
    }
    
    $timeStr = $Timestamp.ToString("HH:mm:ss")
    $dirSymbol = if ($Direction -eq "SEND") { "→" } else { "←" }
    $summary = Get-MessageSummary -Data $Data -MaxLength 50
    
    return [PSCustomObject]@{
        Time = $timeStr
        Direction = $dirSymbol
        Summary = $summary
        Size = $Data.Length
        RawData = $Data
    }
}

# Export-ModuleMember -Function @(
#     'ConvertTo-ByteArray',
#     'ConvertFrom-ByteArray',
#     'Expand-MessageVariables',
#     'Get-MessageSummary',
#     'Read-TemplateFile',
#     'Format-MessageForDisplay'
# )
