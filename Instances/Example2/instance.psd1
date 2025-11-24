@{
    # インスタンス識別子
    Id = "example-server-2"
    
    # UI表示名
    DisplayName = "Example TCP Server 2"
    
    # 説明・用途
    Description = "サンプルTCPサーバー - ローカルホストでの簡易試験用"
    
    # 接続設定
    Connection = @{
        Protocol = "TCP"           # TCP/UDP
        Mode = "Server"           # Client/Server/Sender/Receiver
        LocalIP = "127.0.0.1"
        LocalPort = 8081
        RemoteIP = ""             # Serverモードでは不要
        RemotePort = 0
    }
    
    # 起動設定
    AutoStart = $false           # アプリ起動時に自動接続
    AutoScenario = ""            # 接続後に自動実行するシナリオ
    
    # タグ・グループ（論理ビューでの分類）
    Tags = @("Example", "TCP", "Server")
    Group = "Examples"
    
    # エンコーディング設定
    DefaultEncoding = "UTF-8"
    
    # 性能測定設定
    Performance = @{
        EnableMetrics = $false
        SampleInterval = 1000    # ms
    }
}
