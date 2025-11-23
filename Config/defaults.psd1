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
    
    # ログ出力設定
    EnableFileLogging = $false        # ファイルログ出力（$false で無効化）
    LogBufferSize = 50                # バッファサイズ（エントリ数）
    LogFlushIntervalSeconds = 5       # フラッシュ間隔（秒）
    
    # デバッグ出力設定
    EnableDebugOutput = $false         # コンソールデバッグログ（$false で性能向上）
}
