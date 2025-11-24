# Core/Common/Exceptions.ps1
# カスタム例外クラス定義

<#
.SYNOPSIS
アプリケーションレイヤーの例外

.DESCRIPTION
Use Caseやビジネスロジックの実行中に発生するエラーを表す例外。
ユーザー入力の検証エラー、ビジネスルール違反など。
#>
class ApplicationException : System.Exception {
    [string]$ErrorCode
    [hashtable]$Context
    
    ApplicationException([string]$message) : base($message) {
        $this.ErrorCode = "APP_ERROR"
        $this.Context = @{}
    }
    
    ApplicationException([string]$message, [string]$errorCode) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = @{}
    }
    
    ApplicationException([string]$message, [string]$errorCode, [hashtable]$context) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = if ($context) { $context } else { @{} }
    }
}

<#
.SYNOPSIS
ドメインレイヤーの例外

.DESCRIPTION
ドメインモデルやビジネスロジックの不整合を表す例外。
エンティティの状態遷移エラー、ドメインルール違反など。
#>
class DomainException : System.Exception {
    [string]$ErrorCode
    [hashtable]$Context
    
    DomainException([string]$message) : base($message) {
        $this.ErrorCode = "DOMAIN_ERROR"
        $this.Context = @{}
    }
    
    DomainException([string]$message, [string]$errorCode) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = @{}
    }
    
    DomainException([string]$message, [string]$errorCode, [hashtable]$context) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = if ($context) { $context } else { @{} }
    }
}

<#
.SYNOPSIS
インフラストラクチャレイヤーの例外

.DESCRIPTION
外部システムとの連携、I/O操作、ネットワーク通信などで発生する例外。
TCP接続エラー、ファイル読み込みエラーなど。
#>
class InfrastructureException : System.Exception {
    [string]$ErrorCode
    [hashtable]$Context
    
    InfrastructureException([string]$message) : base($message) {
        $this.ErrorCode = "INFRA_ERROR"
        $this.Context = @{}
    }
    
    InfrastructureException([string]$message, [string]$errorCode) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = @{}
    }
    
    InfrastructureException([string]$message, [string]$errorCode, [hashtable]$context) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = if ($context) { $context } else { @{} }
    }
}

<#
.SYNOPSIS
接続に関する例外

.DESCRIPTION
TCP/UDP接続の確立、切断、送受信に関する特定の例外。
#>
class ConnectionException : InfrastructureException {
    [string]$ConnectionId
    
    ConnectionException([string]$message, [string]$connectionId) : base($message, "CONNECTION_ERROR") {
        $this.ConnectionId = $connectionId
        $this.Context['ConnectionId'] = $connectionId
    }
    
    ConnectionException([string]$message, [string]$connectionId, [string]$errorCode) : base($message, $errorCode) {
        $this.ConnectionId = $connectionId
        $this.Context['ConnectionId'] = $connectionId
    }
}

<#
.SYNOPSIS
設定ファイルに関する例外

.DESCRIPTION
設定ファイルの読み込み、検証に関する例外。
#>
class ConfigurationException : ApplicationException {
    [string]$FilePath
    
    ConfigurationException([string]$message, [string]$filePath) : base($message, "CONFIG_ERROR") {
        $this.FilePath = $filePath
        $this.Context['FilePath'] = $filePath
    }
}

<#
.SYNOPSIS
バリデーションエラー

.DESCRIPTION
入力値やパラメータの検証エラーを表す例外。
#>
class ValidationException : ApplicationException {
    [string]$FieldName
    [object]$InvalidValue
    
    ValidationException([string]$message, [string]$fieldName) : base($message, "VALIDATION_ERROR") {
        $this.FieldName = $fieldName
        $this.Context['FieldName'] = $fieldName
    }
    
    ValidationException([string]$message, [string]$fieldName, [object]$invalidValue) : base($message, "VALIDATION_ERROR") {
        $this.FieldName = $fieldName
        $this.InvalidValue = $invalidValue
        $this.Context['FieldName'] = $fieldName
        $this.Context['InvalidValue'] = $invalidValue
    }
}
