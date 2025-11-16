# QuickSender.ps1
# [DEPRECATED] このモジュールは非推奨です。MessageServiceを直接使用してください。
# データバンク & ワンクリック送信モジュール

if (-not $script:QuickSenderDataBankCache) {
    $script:QuickSenderDataBankCache = @{}
}

function Read-DataBank {
    <#
    .SYNOPSIS
    データバンクCSVを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Warning "DataBank file not found: $FilePath"
        return @()
    }

    return Get-DataBankRows -FilePath $FilePath
}

function Get-DataBankRows {
    <#
    .SYNOPSIS
    データバンクCSVをキャッシュ付きで取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return @()
    }

    $fileInfo = Get-Item -LiteralPath $FilePath
    $lastWrite = $fileInfo.LastWriteTimeUtc

    if ($script:QuickSenderDataBankCache.ContainsKey($FilePath)) {
        $cached = $script:QuickSenderDataBankCache[$FilePath]
        if ($cached.LastWrite -eq $lastWrite) {
            return $cached.Rows
        }
    }

    try {
        $rows = Import-Csv -Path $FilePath -Encoding UTF8
    } catch {
        Write-Warning "Failed to read databank '$FilePath': $_"
        return @()
    }

    $script:QuickSenderDataBankCache[$FilePath] = [PSCustomObject]@{
        LastWrite = $lastWrite
        Rows      = $rows
    }

    return $rows
}

function Get-DataBankEntry {
    <#
    .SYNOPSIS
    データバンクCSVから指定IDの行を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$DataID
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "DataBank file not found: $FilePath"
    }

    $rows = Get-DataBankRows -FilePath $FilePath
    $entry = $rows | Where-Object { $_.DataID -eq $DataID } | Select-Object -First 1

    if (-not $entry) {
        throw "DataID not found in DataBank file: $DataID"
    }

    return $entry
}

function Send-QuickData {
    <#
    .SYNOPSIS
    データバンクからクイック送信
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [string]$DataID,
        
        [Parameter(Mandatory=$false)]
        [array]$DataBank,

        [Parameter(Mandatory=$false)]
        [string]$DataBankPath
    )
    
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId

    if (-not $DataBank -and [string]::IsNullOrWhiteSpace($DataBankPath)) {
        throw "Either DataBank or DataBankPath must be provided."
    }

    # データバンクからDataIDで検索
    if ($DataBank) {
        $dataItem = $DataBank | Where-Object { $_.DataID -eq $DataID } | Select-Object -First 1
    } else {
        $dataItem = Get-DataBankEntry -FilePath $DataBankPath -DataID $DataID
    }
    
    if (-not $dataItem) {
        throw "DataID not found in DataBank: $DataID"
    }
    
    Write-Verbose "[QuickSender] Sending '$DataID' to $($conn.DisplayName)..."
    
    # データタイプに応じて処理
    switch ($dataItem.Type) {
        "TEXT" {
            # 変数展開
            $message = Expand-MessageVariables -Template $dataItem.Content -Variables $conn.Variables
            $bytes = ConvertTo-ByteArray -Data $message -Encoding "UTF-8"
        }
        "HEX" {
            # HEX変換
            $bytes = ConvertTo-ByteArray -Data $dataItem.Content -IsHex
        }
        "FILE" {
            # ファイル読み込み
            if (Test-Path $dataItem.Content) {
                $bytes = [System.IO.File]::ReadAllBytes($dataItem.Content)
            } else {
                throw "File not found: $($dataItem.Content)"
            }
        }
        "TEMPLATE" {
            # テンプレート展開
            $message = Expand-MessageVariables -Template $dataItem.Content -Variables $conn.Variables
            $bytes = ConvertTo-ByteArray -Data $message -Encoding "UTF-8"
        }
        default {
            # デフォルトはTEXT扱い
            $message = Expand-MessageVariables -Template $dataItem.Content -Variables $conn.Variables
            $bytes = ConvertTo-ByteArray -Data $message -Encoding "UTF-8"
        }
    }
    
    # 送信
    Send-Data -ConnectionId $ConnectionId -Data $bytes
    
    Write-Verbose "[QuickSender] Sent '$DataID': $($bytes.Length) bytes"
}

function Send-QuickDataToGroup {
    <#
    .SYNOPSIS
    グループ内の全接続にクイック送信
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$DataID,
        
        [Parameter(Mandatory=$false)]
        [array]$DataBank,

        [Parameter(Mandatory=$false)]
        [string]$DataBankPath
    )
    
    # グループ内の接続を取得
    $connections = Get-ConnectionsByGroup -GroupName $GroupName
    
    if ($connections.Count -eq 0) {
        Write-Warning "No connections found in group: $GroupName"
        return
    }

    if (-not $DataBank -and -not [string]::IsNullOrWhiteSpace($DataBankPath)) {
        $DataBank = Get-DataBankRows -FilePath $DataBankPath
    }
    
    Write-Verbose "[QuickSender] Sending '$DataID' to group '$GroupName' ($($connections.Count) connections)..."
    
    foreach ($conn in $connections) {
        try {
            Send-QuickData -ConnectionId $conn.Id -DataID $DataID -DataBank $DataBank -DataBankPath $DataBankPath
        } catch {
            Write-Error "Failed to send to $($conn.DisplayName): $_"
        }
    }
    
    Write-Verbose "[QuickSender] Group send completed"
}

function Get-DataBankCategories {
    <#
    .SYNOPSIS
    データバンクのカテゴリ一覧を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$DataBank
    )
    
    $categories = $DataBank | Select-Object -ExpandProperty Category -Unique | Sort-Object
    
    return $categories
}

function Get-DataBankByCategory {
    <#
    .SYNOPSIS
    カテゴリでデータバンクをフィルタ
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$DataBank,
        
        [Parameter(Mandatory=$true)]
        [string]$Category
    )
    
    $filtered = $DataBank | Where-Object { $_.Category -eq $Category }
    
    return $filtered
}

function Get-QuickDataCatalog {
    <#
    .SYNOPSIS
    インスタンス配下のクイック送信データ一覧を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )

    $catalog = [PSCustomObject]@{
        Path    = $null
        Entries = @()
    }

    if ([string]::IsNullOrWhiteSpace($InstancePath)) {
        return $catalog
    }

    $databankPath = Join-Path $InstancePath "templates\databank.csv"
    if (-not (Test-Path -LiteralPath $databankPath)) {
        return $catalog
    }

    try {
        $rows = Get-DataBankRows -FilePath $databankPath
        $catalog.Path = $databankPath
        $catalog.Entries = $rows
    }
    catch {
        Write-Warning "[QuickSender] Failed to load quick data bank: $_"
    }

    return $catalog
}

# Export-ModuleMember -Function @(
#     'Read-DataBank',
#     'Send-QuickData',
#     'Send-QuickDataToGroup',
#     'Get-DataBankCategories',
#     'Get-DataBankByCategory'
# )

