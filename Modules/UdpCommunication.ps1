# UdpCommunication.ps1
# UDP通信管理 (新アーキテクチャ、アダプターのラッパー)

function Start-UdpConnection {
    <#
    .SYNOPSIS
    UDP通信を開始
    
    .DESCRIPTION
    新アーキテクチャのアダプターを使用して、接続を開始します。
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Connection
    )
    
    # ServiceContainerが必要
    if (-not $Global:ServiceContainer) {
        throw "ServiceContainer is not initialized. Please run TcpDebugger.ps1 first."
    }
    
    # UdpAdapterを取得
    $adapter = $Global:ServiceContainer.Resolve('UdpAdapter')
    
    # ManagedConnectionオブジェクトの場合
    if ($Connection -is [ManagedConnection]) {
        $adapter.Start($Connection.Id)
        return
    }
    
    # 旧型接続オブジェクトの場合、ConnectionServiceから登録確認
    if ($Connection.Id -and $Global:ConnectionService) {
        $managedConn = $Global:ConnectionService.GetConnection($Connection.Id)
        if ($managedConn) {
            $adapter.Start($Connection.Id)
            return
        }
    }
    
    # 未登録の場合はエラー
    throw "Connection '$($Connection.Id)' is not registered in ConnectionService. Please use ConnectionService.AddConnection() first."
}



