# MessageHandler.ps1
# 電文処理モジュール - エンコード/デコード/変数展開

function ConvertTo-ByteArray {
    <#
    .SYNOPSIS
    文字列をバイト配列に変換
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Data,
        
        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8",
        
        [Parameter(Mandatory=$false)]
        [switch]$IsHex
    )
    
    if ($IsHex) {
        # HEX文字列をバイト配列に変換
        # スペース、ハイフン、0x接頭辞を除去
        $cleanHex = $Data -replace '[\s\-]', '' -replace '0x', ''
        
        $bytes = @()
        for ($i = 0; $i -lt $cleanHex.Length; $i += 2) {
            $hexByte = $cleanHex.Substring($i, 2)
            $bytes += [Convert]::ToByte($hexByte, 16)
        }
        
        return [byte[]]$bytes
        
    } else {
        # テキストエンコーディング
        switch ($Encoding) {
            "ASCII" {
                return [System.Text.Encoding]::ASCII.GetBytes($Data)
            }
            "UTF-8" {
                return [System.Text.Encoding]::UTF8.GetBytes($Data)
            }
            "Shift-JIS" {
                $sjis = [System.Text.Encoding]::GetEncoding("Shift_JIS")
                return $sjis.GetBytes($Data)
            }
            default {
                return [System.Text.Encoding]::UTF8.GetBytes($Data)
            }
        }
    }
}

function ConvertFrom-ByteArray {
    <#
    .SYNOPSIS
    バイト配列を文字列に変換
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$false)]
        [string]$Encoding = "UTF-8",
        
        [Parameter(Mandatory=$false)]
        [switch]$AsHex
    )
    
    if ($AsHex) {
        # バイト配列をHEX文字列に変換
        $hexString = ($Data | ForEach-Object { $_.ToString("X2") }) -join ' '
        return $hexString
        
    } else {
        # バイトからテキストに変換
        switch ($Encoding) {
            "ASCII" {
                return [System.Text.Encoding]::ASCII.GetString($Data)
            }
            "UTF-8" {
                return [System.Text.Encoding]::UTF8.GetString($Data)
            }
            "Shift-JIS" {
                $sjis = [System.Text.Encoding]::GetEncoding("Shift_JIS")
                return $sjis.GetString($Data)
            }
            default {
                return [System.Text.Encoding]::UTF8.GetString($Data)
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
    
    $result = $Template
    
    # ${変数名} パターンを展開
    $pattern = '\$\{([^}]+)\}'
    $regexMatches = [regex]::Matches($result, $pattern)
    
    foreach ($match in $regexMatches) {
        $varName = $match.Groups[1].Value
        $replacement = ""
        
        # 特殊変数処理
        if ($varName -eq "TIMESTAMP") {
            $replacement = Get-Date -Format "yyyyMMddHHmmss"
            
        } elseif ($varName -like "DATETIME:*") {
            $format = $varName.Substring(9)
            $replacement = Get-Date -Format $format
            
        } elseif ($varName -like "RANDOM:*") {
            $range = $varName.Substring(7) -split '-'
            if ($range.Count -eq 2) {
                $min = [int]$range[0]
                $max = [int]$range[1]
                $replacement = Get-Random -Minimum $min -Maximum $max
            }
            
        } elseif ($varName -like "SEQ:*") {
            $seqName = $varName.Substring(4)
            $seqKey = "SEQ_$seqName"
            
            if ($Variables.ContainsKey($seqKey)) {
                $Variables[$seqKey] = [int]$Variables[$seqKey] + 1
            } else {
                $Variables[$seqKey] = 1
            }
            $replacement = $Variables[$seqKey]
            
        } elseif ($varName -like "HEX:*") {
            $hexValue = $varName.Substring(4)
            $replacement = $hexValue
            
        } elseif ($varName -like "CALC:*") {
            $expression = $varName.Substring(5)
            try {
                $replacement = Invoke-Expression $expression
            } catch {
                Write-Warning "Failed to evaluate expression: $expression"
                $replacement = ""
            }
            
        } elseif ($Variables.ContainsKey($varName)) {
            # ユーザー定義変数
            $replacement = $Variables[$varName]
            
        } else {
            Write-Warning "Variable not found: $varName"
            $replacement = ""
        }
        
        $result = $result.Replace($match.Value, $replacement)
    }
    
    return $result
}

function Get-MessageSummary {
    <#
    .SYNOPSIS
    メッセージのサマリを取得（表示用）
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
        
        # 制御文字を除去
        $text = $text -replace '[\x00-\x1F\x7F]', '.'
        
        # 長さ制限
        if ($text.Length -gt $MaxLength) {
            $text = $text.Substring(0, $MaxLength) + "..."
        }
        
        return $text
        
    } catch {
        # デコード失敗時はHEX表示
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
    
    if (-not (Test-Path $FilePath)) {
        throw "Template file not found: $FilePath"
    }
    
    $templates = @{}
    
    # CSV形式で読み込み
    $csv = Import-Csv -Path $FilePath -Encoding UTF8
    
    foreach ($row in $csv) {
        $templates[$row.TemplateName] = [PSCustomObject]@{
            Name = $row.TemplateName
            Format = $row.MessageFormat
            Encoding = $row.Encoding
        }
    }
    
    return $templates
}

function Format-MessageForDisplay {
    <#
    .SYNOPSIS
    送受信ログ表示用にメッセージを整形
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
    $dirSymbol = if ($Direction -eq "SEND") { "▲" } else { "▼" }
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
