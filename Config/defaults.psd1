@{
    # デフォルト設定スナップショット
    
    # 接続タイムアウト（ミリ秒）
    ConnectionTimeout = 5000
    
    # 受信バッファサイズ（バイト）
    ReceiveBufferSize = 8192
    
    # 送信バッファサイズ（バイト）
    SendBufferSize = 8192
    
    # 再接続試行回数
    ReconnectAttempts = 3
    
    # 再接続間隔（ミリ秒）
    ReconnectInterval = 1000
    
    # ログ保持件数（メモリ上）
    LogRetentionCount = 100
    
    # デフォルトエンコーディング
    DefaultEncoding = "UTF-8"
    
    # ターミナル出力設定（性能優先時は $false に設定）
    EnableConsoleOutput = $true        # 全てのコンソール出力を制御（$false で完全静音モード）
}
