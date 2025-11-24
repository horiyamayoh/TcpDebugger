# 命名規則の統一 (2025-11-24)

## 背景

以前の機能名（Auto Response、On Received、Periodic Send、Quick Data、Quick Action）は、トリガーとアクションの関係が不明確で、直感的に理解しにくい状況でした。

この問題を解決するため、**トリガー + アクション**の明確な体系に基づいた新しい命名規則を採用しました。

## 新しい命名規則

### トリガーベースの体系

```
【手動操作】
- Manual: Send    → 手動でテンプレート送信
- Manual: Script  → 手動でスクリプト実行

【受信時自動】  
- On Receive: Reply  → 受信時に自動返信
- On Receive: Script → 受信時にスクリプト実行

【定期自動】
- On Timer: Send → タイマーで定期送信
```

## 変更内容の詳細

### UI表示名の変更

| 旧名称 | 新名称 | 説明 |
|--------|--------|------|
| Quick Data | Manual: Send | テンプレートデータを手動送信 |
| Quick Action | Manual: Script | スクリプトを手動実行 |
| Auto Response | On Receive: Reply | 受信時に自動返信 |
| On Received | On Receive: Script | 受信時にスクリプト実行 |
| Periodic Send | On Timer: Send | タイマーで定期送信 |

### フォルダ構造の変更

インスタンスフォルダ内の`scenarios/`配下:

| 旧フォルダ名 | 新フォルダ名 |
|------------|------------|
| `scenarios/auto/` | `scenarios/on_receive_reply/` |
| `scenarios/onreceived/` | `scenarios/on_receive_script/` |
| `scenarios/periodic/` | `scenarios/on_timer_send/` |

### CSVヘッダーの変更

`profiles.csv`のヘッダー:

| 旧ヘッダー | 新ヘッダー |
|----------|----------|
| AutoResponseScenario | OnReceiveReply |
| OnReceivedScenario | OnReceiveScript |
| PeriodicScenario | OnTimerSend |

### ログ出力の変更

内部ログタグの統一:

- `[PeriodicSend]` → `[OnTimerSend]`
- コメント内の用語も新命名規則に統一

## 影響を受けるファイル

### コードファイル
- `Presentation/UI/ViewBuilder.ps1` - 列ヘッダー名の変更
- `Presentation/UI/MainForm.ps1` - エラーメッセージの更新
- `Core/Domain/ProfileService.ps1` - CSVヘッダー名の変更
- `Core/Domain/ReceivedRuleEngine.ps1` - フォルダパスの更新
- `Core/Application/InstanceManager.ps1` - フォルダパスの更新
- `Core/Domain/ConnectionManager.ps1` - ログメッセージの更新
- `Core/Application/ConnectionManager.ps1` - ログメッセージの更新

### ドキュメント
- `README.md` - 全体的な用語の統一
- `DESIGN.md` - 設計書内の用語の統一
- `Docs/ReceivedRuleFormat.md` - ルール形式ドキュメントの更新

### 設定ファイル
- `Instances/Example/profiles.csv` - CSVヘッダーの更新

### フォルダ構造
- `Instances/Example/scenarios/auto/` → `scenarios/on_receive_reply/`
- `Instances/Example/scenarios/onreceived/` → `scenarios/on_receive_script/`
- `Instances/Example/scenarios/periodic/` → `scenarios/on_timer_send/`

## 後方互換性

すべての内部関数名と変数名も新しい命名規則に統一しました:

### 関数名の変更
- `Get-QuickDataCatalog` → `Get-ManualSendCatalog`
- `Get-InstanceAutoResponseProfiles` → `Get-InstanceOnReceiveReplyProfiles`
- `Get-InstanceOnReceivedProfiles` → `Get-InstanceOnReceiveScriptProfiles`
- `Get-InstancePeriodicSendProfiles` → `Get-InstanceOnTimerSendProfiles`
- `Set-ConnectionPeriodicSendProfile` → `Set-ConnectionOnTimerSendProfile`
- `Set-ConnectionOnReceivedProfile` → `Set-ConnectionOnReceiveScriptProfile`
- `Set-ConnectionAutoResponseProfile` → `Set-ConnectionOnReceiveReplyProfile`
- `Configure-QuickDataColumn` → `Configure-ManualSendColumn`
- `Configure-QuickActionColumn` → `Configure-ManualScriptColumn`
- `Configure-OnReceivedColumn` → `Configure-OnReceiveScriptColumn`
- `Configure-PeriodicSendColumn` → `Configure-OnTimerSendColumn`
- `Apply-AutoResponseProfile` → `Apply-OnReceiveReplyProfile`
- `Apply-PeriodicSendProfile` → `Apply-OnTimerSendProfile`
- `Apply-OnReceivedProfile` → `Apply-OnReceiveScriptProfile`
- `Handle-PeriodicSendChanged` → `Handle-OnTimerSendChanged`
- `Handle-OnReceivedChanged` → `Handle-OnReceiveScriptChanged`

### 変数名の変更
- `$colQuickData` → `$colManualSend`
- `$colQuickAction` → `$colManualScript`
- `$colAutoResponse` → `$colOnReceiveReply`
- `$colOnReceived` → `$colOnReceiveScript`
- `$colPeriodicSend` → `$colOnTimerSend`

これにより、コードベース全体が統一された命名規則に従うようになりました。

## 今後の拡張性

この命名規則により、将来的に以下のような拡張が容易になります:

- `On Receive: Transform` - 受信時にデータ変換
- `On Timer: Script` - タイマーでスクリプト実行
- `Manual: Transform` - 手動でデータ変換
- `On Connect: Script` - 接続時にスクリプト実行

トリガー（Manual/OnReceive/OnTimer/OnConnect等）とアクション（Send/Script/Reply/Transform等）の組み合わせで、論理的に機能を整理できます。
