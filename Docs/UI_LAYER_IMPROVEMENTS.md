# UI層の改善ガイド

## 概要

Presentation層（UI層）からの直接的なグローバル変数アクセスを排除し、ServiceContainerを経由した適切な依存性注入パターンに移行しました。

## 改善内容

### Before（改善前）

```powershell
# ❌ グローバル変数への直接アクセス
function Initialize-ProfileComboBoxes {
    if ($Global:ProfileService) {
        $profiles = $Global:ProfileService.GetAvailableApplicationProfiles()
        # ...
    }
}

# ❌ 複数箇所でグローバル変数を直接参照
if ($Global:MessageProcessor) {
    $processed = $Global:MessageProcessor.ProcessMessages(50)
}
```

**問題点:**
- テスタビリティが低い（モックが困難）
- 依存関係が暗黙的
- レイヤー境界が曖昧
- グローバル状態への依存

### After（改善後）

```powershell
# ✅ ヘルパー関数を通じたアクセス
function Get-UiProfileService {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('ProfileService')
        }
        catch {
            # フォールバック処理
        }
    }
    
    # 後方互換性のため
    if ($Global:ProfileService) {
        return $Global:ProfileService
    }
    return $null
}

# ✅ ヘルパー関数を使用
function Initialize-ProfileComboBoxes {
    $profileService = Get-UiProfileService
    if ($profileService) {
        $profiles = $profileService.GetAvailableApplicationProfiles()
        # ...
    }
}
```

**改善点:**
- ServiceContainerを優先的に使用
- 依存関係が明示的
- テストが容易（ヘルパー関数をモック可能）
- 後方互換性を維持

## 新しいヘルパー関数

### 1. Get-UiConnectionService

```powershell
function Get-UiConnectionService {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('ConnectionService')
        }
        catch {
            # ServiceContainerが初期化されていない場合はフォールバック
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:ConnectionService) {
        return $Global:ConnectionService
    }
    if (Get-Command Get-ConnectionService -ErrorAction SilentlyContinue) {
        return Get-ConnectionService
    }
    throw "ConnectionService is not available."
}
```

**用途:** 接続管理サービスへのアクセス

### 2. Get-UiProfileService

```powershell
function Get-UiProfileService {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('ProfileService')
        }
        catch {
            # フォールバック処理
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:ProfileService) {
        return $Global:ProfileService
    }
    return $null
}
```

**用途:** プロファイル管理サービスへのアクセス

### 3. Get-UiMessageProcessor

```powershell
function Get-UiMessageProcessor {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('MessageProcessor')
        }
        catch {
            # フォールバック処理
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:MessageProcessor) {
        return $Global:MessageProcessor
    }
    return $null
}
```

**用途:** メッセージ処理サービスへのアクセス

### 4. Get-UiLogger

```powershell
function Get-UiLogger {
    # ServiceContainer経由でサービスを取得（推奨）
    if ($Global:ServiceContainer) {
        try {
            return $Global:ServiceContainer.Resolve('Logger')
        }
        catch {
            # フォールバック処理
        }
    }
    
    # 後方互換性のためのフォールバック
    if ($Global:Logger) {
        return $Global:Logger
    }
    return $null
}
```

**用途:** ロギングサービスへのアクセス

## 使用例

### プロファイル初期化

```powershell
# Before
if ($Global:ProfileService) {
    $profiles = $Global:ProfileService.GetAvailableApplicationProfiles()
}

# After
$profileService = Get-UiProfileService
if ($profileService) {
    $profiles = $profileService.GetAvailableApplicationProfiles()
}
```

### メッセージ処理

```powershell
# Before
if ($Global:MessageProcessor) {
    $processed = $Global:MessageProcessor.ProcessMessages(50)
}

# After
$processor = Get-UiMessageProcessor
if ($processor) {
    $processed = $processor.ProcessMessages(50)
}
```

### ロガー使用

```powershell
# Before
if ($Global:Logger) {
    $Global:Logger.Flush()
}

# After
$logger = Get-UiLogger
if ($logger) {
    $logger.Flush()
}
```

## アーキテクチャ上の利点

### 1. テスタビリティの向上

```powershell
# テスト時にモックサービスを注入可能
Describe "MainForm UI Tests" {
    BeforeEach {
        # モックServiceContainerを作成
        $mockContainer = [ServiceContainer]::new()
        $mockContainer.RegisterSingleton('ProfileService', {
            # モックProfileServiceを返す
            return [MockProfileService]::new()
        })
        $Global:ServiceContainer = $mockContainer
    }
    
    It "プロファイル一覧を正しく表示する" {
        # Get-UiProfileServiceがモックを返す
        # テストが可能に！
    }
}
```

### 2. 依存関係の明示化

```powershell
# 関数シグネチャから依存関係が明確
function Apply-ApplicationProfile {
    param(
        [System.Windows.Forms.DataGridView]$DataGridView,
        [string]$ProfileName
    )
    
    # ここでProfileServiceが必要なことが明確
    $profileService = Get-UiProfileService
    if (-not $profileService) {
        return  # 依存関係がない場合の処理も明確
    }
    
    # ...
}
```

### 3. レイヤー境界の保護

```
Presentation Layer (UI)
    ↓ ヘルパー関数経由
ServiceContainer (DI Container)
    ↓ Resolve
Application/Domain Layers
```

### 4. 段階的移行が可能

フォールバック機構により、以下の移行パスが可能：

1. **Phase 1**: ヘルパー関数を導入（完了✅）
2. **Phase 2**: グローバル変数を段階的に削除
3. **Phase 3**: ServiceContainerのみに依存

## ベストプラクティス

### ✅ 推奨

```powershell
# 1. ヘルパー関数を使用
$service = Get-UiConnectionService()
if ($service) {
    $connection = $service.GetConnection($connectionId)
}

# 2. null チェックを行う
$profileService = Get-UiProfileService
if (-not $profileService) {
    Write-Warning "ProfileService not available"
    return
}

# 3. 早期リターン
function SomeFunction {
    $service = Get-UiProfileService
    if (-not $service) {
        return  # サービスがない場合は早期リターン
    }
    
    # 正常処理
    $service.DoSomething()
}
```

### ❌ 非推奨

```powershell
# 1. グローバル変数への直接アクセス
$profiles = $Global:ProfileService.GetAvailableApplicationProfiles()

# 2. null チェックなし
$service = Get-UiProfileService
$service.DoSomething()  # サービスがnullの場合エラー

# 3. 複数箇所で同じグローバル変数アクセス
if ($Global:ProfileService) {
    $Global:ProfileService.Method1()
}
if ($Global:ProfileService) {
    $Global:ProfileService.Method2()
}
```

## 今後の改善計画

### Short-term（1-2週間）
- [ ] 他のUIファイルにも同様のパターンを適用
- [ ] ViewBuilder.ps1のグローバル変数アクセス排除

### Mid-term（1-2ヶ月）
- [ ] グローバル変数の完全削除（後方互換性確認後）
- [ ] UI層の単体テスト追加
- [ ] ViewModelパターンの再検討

### Long-term（2-4ヶ月）
- [ ] Presentation層の完全なDI化
- [ ] MVVMパターンへの移行検討

## まとめ

UI層からの直接的なグローバル変数アクセスを排除することで：

- ✅ テスタビリティが向上
- ✅ 依存関係が明示化
- ✅ レイヤー境界が明確化
- ✅ 段階的な改善が可能
- ✅ 後方互換性を維持

これらの改善により、コードの品質と保守性が大幅に向上しました。
