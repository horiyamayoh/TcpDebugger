# Core/Domain/RunspaceMessages.ps1
# Runspace間通信用のメッセージ型定義

<#
.SYNOPSIS
メッセージタイプの列挙型

.DESCRIPTION
Runspaceから UIスレッドへ送信されるメッセージの種類を定義
#>
enum MessageType {
    StatusUpdate      # 接続状態の変更 (CONNECTING, CONNECTED, DISCONNECTED, ERROR)
    DataReceived      # データ受信イベント
    ErrorOccurred     # エラー発生
    ActivityMarker    # 最終アクティビティ時刻更新
    SocketUpdate      # ソケット状態更新 (Socket設定/クリア)
    LogMessage        # ログメッセージ
    SendRequest       # データ送信リクエスト (将来の拡張用)
}

<#
.SYNOPSIS
Runspace間通信用のメッセージクラス

.DESCRIPTION
すべてのメッセージタイプの基底クラス。
Type、ConnectionId、Timestamp、Dataを持つ。
#>
class RunspaceMessage {
    [MessageType]$Type
    [string]$ConnectionId
    [datetime]$Timestamp
    [hashtable]$Data
    
    RunspaceMessage([MessageType]$type, [string]$connId, [hashtable]$data) {
        if ([string]::IsNullOrWhiteSpace($connId)) {
            throw "ConnectionId cannot be null or empty"
        }
        
        $this.Type = $type
        $this.ConnectionId = $connId
        $this.Timestamp = Get-Date
        $this.Data = if ($data) { $data } else { @{} }
    }
    
    [string] ToString() {
        return "[{0}] {1} @ {2:HH:mm:ss.fff}" -f $this.Type, $this.ConnectionId, $this.Timestamp
    }
}

<#
.SYNOPSIS
接続状態更新メッセージを作成

.PARAMETER ConnectionId
接続ID

.PARAMETER Status
新しい状態 (CONNECTING, CONNECTED, DISCONNECTED, ERROR)

.EXAMPLE
$msg = New-StatusUpdateMessage -ConnectionId "conn-001" -Status "CONNECTED"
#>
function New-StatusUpdateMessage {
    [OutputType([RunspaceMessage])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory)]
        [string]$Status
    )
    
    return [RunspaceMessage]::new(
        [MessageType]::StatusUpdate,
        $ConnectionId,
        @{ Status = $Status }
    )
}

<#
.SYNOPSIS
データ受信メッセージを作成

.PARAMETER ConnectionId
接続ID

.PARAMETER Data
受信したバイトデータ

.PARAMETER Metadata
メタデータ (RemoteEndpoint など)

.EXAMPLE
$msg = New-DataReceivedMessage -ConnectionId "conn-001" -Data $bytes -Metadata @{ RemoteEndpoint = "192.168.1.100:8080" }
#>
function New-DataReceivedMessage {
    [OutputType([RunspaceMessage])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory)]
        [byte[]]$Data,
        
        [hashtable]$Metadata = @{}
    )
    
    return [RunspaceMessage]::new(
        [MessageType]::DataReceived,
        $ConnectionId,
        @{ 
            Data = $Data
            Metadata = $Metadata
        }
    )
}

<#
.SYNOPSIS
エラー発生メッセージを作成

.PARAMETER ConnectionId
接続ID

.PARAMETER Message
エラーメッセージ

.PARAMETER Exception
例外オブジェクト (オプション)

.EXAMPLE
$msg = New-ErrorMessage -ConnectionId "conn-001" -Message "Connection refused" -Exception $_.Exception
#>
function New-ErrorMessage {
    [OutputType([RunspaceMessage])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Exception]$Exception = $null
    )
    
    return [RunspaceMessage]::new(
        [MessageType]::ErrorOccurred,
        $ConnectionId,
        @{ 
            Message = $Message
            Exception = $Exception
        }
    )
}

<#
.SYNOPSIS
アクティビティマーカーメッセージを作成

.PARAMETER ConnectionId
接続ID

.DESCRIPTION
接続の最終アクティビティ時刻を更新するためのメッセージ

.EXAMPLE
$msg = New-ActivityMessage -ConnectionId "conn-001"
#>
function New-ActivityMessage {
    [OutputType([RunspaceMessage])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionId
    )
    
    return [RunspaceMessage]::new(
        [MessageType]::ActivityMarker,
        $ConnectionId,
        @{}
    )
}

<#
.SYNOPSIS
ソケット更新メッセージを作成

.PARAMETER ConnectionId
接続ID

.PARAMETER Socket
ソケットオブジェクト ($nullの場合はクリア)

.EXAMPLE
$msg = New-SocketUpdateMessage -ConnectionId "conn-001" -Socket $tcpClient
$msg = New-SocketUpdateMessage -ConnectionId "conn-001" -Socket $null  # クリア
#>
function New-SocketUpdateMessage {
    [OutputType([RunspaceMessage])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionId,
        
        [object]$Socket = $null
    )
    
    return [RunspaceMessage]::new(
        [MessageType]::SocketUpdate,
        $ConnectionId,
        @{ Socket = $Socket }
    )
}

<#
.SYNOPSIS
ログメッセージを作成

.PARAMETER ConnectionId
接続ID

.PARAMETER Level
ログレベル (Info, Warning, Error)

.PARAMETER Message
ログメッセージ

.PARAMETER Context
ログコンテキスト (追加情報)

.EXAMPLE
$msg = New-LogMessage -ConnectionId "conn-001" -Level "Info" -Message "Data sent" -Context @{ Length = 1024 }
#>
function New-LogMessage {
    [OutputType([RunspaceMessage])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [hashtable]$Context = @{}
    )
    
    return [RunspaceMessage]::new(
        [MessageType]::LogMessage,
        $ConnectionId,
        @{
            Level = $Level
            Message = $Message
            Context = $Context
        }
    )
}

<#
.SYNOPSIS
送信リクエストメッセージを作成 (将来の拡張用)

.PARAMETER ConnectionId
接続ID

.PARAMETER Data
送信するバイトデータ

.EXAMPLE
$msg = New-SendRequestMessage -ConnectionId "conn-001" -Data $bytes
#>
function New-SendRequestMessage {
    [OutputType([RunspaceMessage])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionId,
        
        [Parameter(Mandatory)]
        [byte[]]$Data
    )
    
    return [RunspaceMessage]::new(
        [MessageType]::SendRequest,
        $ConnectionId,
        @{ Data = $Data }
    )
}

