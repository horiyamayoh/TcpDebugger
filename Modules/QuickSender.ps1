# QuickSender.ps1
# データバンク & ワンクリック送信モジュール

function Read-DataBank {
    <#
    .SYNOPSIS
    データバンクCSVを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "DataBank file not found: $FilePath"
        return @()
    }
    
    # CSV読み込み
    $dataBank = Import-Csv -Path $FilePath -Encoding UTF8
    
    Write-Host "[QuickSender] Loaded $($dataBank.Count) data items from $FilePath" -ForegroundColor Green
    
    return $dataBank
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
        
        [Parameter(Mandatory=$true)]
        [array]$DataBank
    )
    
    if (-not $Global:Connections.ContainsKey($ConnectionId)) {
        throw "Connection not found: $ConnectionId"
    }
    
    # データバンクからDataIDで検索
    $dataItem = $DataBank | Where-Object { $_.DataID -eq $DataID } | Select-Object -First 1
    
    if (-not $dataItem) {
        throw "DataID not found in DataBank: $DataID"
    }
    
    $conn = $Global:Connections[$ConnectionId]
    
    Write-Host "[QuickSender] Sending '$DataID' to $($conn.DisplayName)..." -ForegroundColor Cyan
    
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
    
    Write-Host "[QuickSender] Sent '$DataID': $($bytes.Length) bytes" -ForegroundColor Blue
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
        
        [Parameter(Mandatory=$true)]
        [array]$DataBank
    )
    
    # グループ内の接続を取得
    $connections = Get-ConnectionsByGroup -GroupName $GroupName
    
    if ($connections.Count -eq 0) {
        Write-Warning "No connections found in group: $GroupName"
        return
    }
    
    Write-Host "[QuickSender] Sending '$DataID' to group '$GroupName' ($($connections.Count) connections)..." -ForegroundColor Cyan
    
    foreach ($conn in $connections) {
        try {
            Send-QuickData -ConnectionId $conn.Id -DataID $DataID -DataBank $DataBank
        } catch {
            Write-Error "Failed to send to $($conn.DisplayName): $_"
        }
    }
    
    Write-Host "[QuickSender] Group send completed" -ForegroundColor Green
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

# Export-ModuleMember -Function @(
#     'Read-DataBank',
#     'Send-QuickData',
#     'Send-QuickDataToGroup',
#     'Get-DataBankCategories',
#     'Get-DataBankByCategory'
# )
