# OnReceiveScriptLibrary.ps1
# OnReceiveScriptスクリプト用のヘルパー関数ライブラリ

function Get-ByteSlice {
    <#
    .SYNOPSIS
    バイト配列から指定範囲をスライス
    
    .EXAMPLE
    $data = Get-ByteSlice -Data $ReceivedData -Offset 0 -Length 2
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,

        [Parameter(Mandatory=$true)]
        [int]$Offset,

        [Parameter(Mandatory=$true)]
        [int]$Length
    )

    if ($Offset -lt 0 -or $Length -le 0) {
        throw "Invalid offset ($Offset) or length ($Length)"
    }

    if ($Offset + $Length -gt $Data.Length) {
        throw "Slice range exceeds data length (Offset: $Offset, Length: $Length, DataLength: $($Data.Length))"
    }

    $result = New-Object byte[] $Length
    [Array]::Copy($Data, $Offset, $result, 0, $Length)
    return $result
}

function Set-ByteSlice {
    <#
    .SYNOPSIS
    バイト配列の指定位置にデータをコピー
    
    .EXAMPLE
    Set-ByteSlice -Target $messageData -Offset 4 -Source $idBytes
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Target,

        [Parameter(Mandatory=$true)]
        [int]$Offset,

        [Parameter(Mandatory=$true)]
        [byte[]]$Source
    )

    if ($Offset -lt 0) {
        throw "Invalid offset: $Offset"
    }

    if ($Offset + $Source.Length -gt $Target.Length) {
        throw "Source data exceeds target bounds (Offset: $Offset, SourceLength: $($Source.Length), TargetLength: $($Target.Length))"
    }

    [Array]::Copy($Source, 0, $Target, $Offset, $Source.Length)
}

function Read-MessageFile {
    <#
    .SYNOPSIS
    電文定義ファイルを読み込んでバイト配列を取得
    
    .EXAMPLE
    $responseData = Read-MessageFile -FilePath "response.csv"
    $responseData = Read-MessageFile -FilePath "response.csv" -InstancePath $Context.InstancePath
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [string]$InstancePath
    )

    $resolvedPath = $FilePath

    # 相対パスの場合、インスタンスのtemplatesフォルダから解決
    if (-not [System.IO.Path]::IsPathRooted($resolvedPath)) {
        if ($InstancePath) {
            $resolvedPath = Join-Path $InstancePath "templates\$FilePath"
        }
    }

    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Message file not found: $resolvedPath"
    }

    # 電文テンプレートを読み込み
    $templates = Get-MessageTemplateCache -FilePath $resolvedPath -ThrowOnMissing

    if (-not $templates.ContainsKey('DEFAULT')) {
        throw "DEFAULT template not found in $resolvedPath"
    }

    $template = $templates['DEFAULT']
    
    # 16進数ストリームをバイト配列に変換
    $bytes = ConvertTo-ByteArray -Data $template.Format -Encoding 'HEX'
    
    return $bytes
}

function Write-MessageFile {
    <#
    .SYNOPSIS
    バイト配列を電文定義ファイルに書き込み
    
    .EXAMPLE
    Write-MessageFile -Data $messageData -FilePath "output.csv" -InstancePath $Context.InstancePath
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,

        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [string]$InstancePath,

        [Parameter(Mandatory=$false)]
        [int]$BytesPerRow = 16
    )

    $resolvedPath = $FilePath

    # 相対パスの場合、インスタンスのtemplatesフォルダから解決
    if (-not [System.IO.Path]::IsPathRooted($resolvedPath)) {
        if ($InstancePath) {
            $resolvedPath = Join-Path $InstancePath "templates\$FilePath"
        }
    }

    # ディレクトリが存在しない場合は作成
    $directory = [System.IO.Path]::GetDirectoryName($resolvedPath)
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    # バイト配列を16進数文字列に変換し、適切な行に分割
    $hexString = ($Data | ForEach-Object { $_.ToString("X2") }) -join ''
    
    $lines = @()
    $offset = 0
    $rowNumber = 1

    while ($offset -lt $hexString.Length) {
        $bytesInRow = [Math]::Min($BytesPerRow * 2, $hexString.Length - $offset)
        $hexPart = $hexString.Substring($offset, $bytesInRow)
        $lines += "Row${rowNumber},$hexPart"
        $offset += $bytesInRow
        $rowNumber++
    }

    # UTF-8で書き込み
    $utf8Encoding = [System.Text.UTF8Encoding]::new($false)  # BOMなし
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $utf8Encoding)
}

function Send-MessageFile {
    <#
    .SYNOPSIS
    電文定義ファイルを読み込んで送信
    
    .EXAMPLE
    Send-MessageFile -ConnectionId $Context.ConnectionId -FilePath "response.csv" -InstancePath $Context.InstancePath
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [string]$InstancePath
    )

    $data = Read-MessageFile -FilePath $FilePath -InstancePath $InstancePath
    Send-Data -ConnectionId $ConnectionId -Data $data
    
    $hexPreview = ($data[0..[Math]::Min(15, $data.Length-1)] | ForEach-Object { $_.ToString("X2") }) -join ' '
    if ($data.Length -gt 16) {
        $hexPreview += "..."
    }
    Write-Console "[OnReceive:Script] Sent message from $FilePath ($($data.Length) bytes: $hexPreview)" -ForegroundColor Magenta
}

function Send-MessageData {
    <#
    .SYNOPSIS
    バイト配列を送信
    
    .EXAMPLE
    Send-MessageData -ConnectionId $Context.ConnectionId -Data $messageBytes
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,

        [Parameter(Mandatory=$true)]
        [byte[]]$Data
    )

    Send-Data -ConnectionId $ConnectionId -Data $Data
    
    $hexPreview = ($Data[0..[Math]::Min(15, $Data.Length-1)] | ForEach-Object { $_.ToString("X2") }) -join ' '
    if ($Data.Length -gt 16) {
        $hexPreview += "..."
    }
    Write-Console "[OnReceive:Script] Sent message ($($Data.Length) bytes: $hexPreview)" -ForegroundColor Magenta
}

function ConvertTo-HexString {
    <#
    .SYNOPSIS
    バイト配列を16進数文字列に変換
    
    .EXAMPLE
    $hex = ConvertTo-HexString -Data $bytes
    $hex = ConvertTo-HexString -Data $bytes -Separator " "
    #>
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,

        [Parameter(Mandatory=$false)]
        [string]$Separator = ""
    )

    return ($Data | ForEach-Object { $_.ToString("X2") }) -join $Separator
}

function ConvertFrom-HexString {
    <#
    .SYNOPSIS
    16進数文字列をバイト配列に変換
    
    .EXAMPLE
    $bytes = ConvertFrom-HexString -HexString "0102030A"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$HexString
    )

    $cleanHex = $HexString -replace '[\s-]', '' -replace '0x', ''
    
    if ($cleanHex.Length % 2 -ne 0) {
        throw "Hex string must have an even number of characters"
    }

    $bytes = @()
    for ($i = 0; $i -lt $cleanHex.Length; $i += 2) {
        $hexByte = $cleanHex.Substring($i, 2)
        $bytes += [Convert]::ToByte($hexByte, 16)
    }

    return [byte[]]$bytes
}

function Get-ConnectionVariable {
    <#
    .SYNOPSIS
    コネクション変数を取得
    
    .EXAMPLE
    $counter = Get-ConnectionVariable -Connection $Context.Connection -Name "Counter" -Default 0
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [object]$Default = $null
    )

    if ($Connection.Variables.ContainsKey($Name)) {
        return $Connection.Variables[$Name]
    }

    return $Default
}

function Set-ConnectionVariable {
    <#
    .SYNOPSIS
    コネクション変数を設定
    
    .EXAMPLE
    Set-ConnectionVariable -Connection $Context.Connection -Name "Counter" -Value 1
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [object]$Value
    )

    $Connection.Variables[$Name] = $Value
}

function Write-OnReceiveScriptLog {
    <#
    .SYNOPSIS
    OnReceiveScriptスクリプトからログ出力
    
    .EXAMPLE
    Write-OnReceiveScriptLog "Processing message ID: $messageId"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Console "[OnReceive:Script] $Message" -ForegroundColor Cyan
}

