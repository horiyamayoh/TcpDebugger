# 命名変更計画

## 変更対象の整理

### 1. ログ出力メッセージ（ユーザー向け）
**変更方針**: 新しい命名規則に統一

- `[AutoResponse]` → `[OnReceiveReply]`
- `[OnReceived]` → `[OnReceiveScript]`  
- `[PeriodicSend]`/`[OnTimerSend]` → `[OnTimerSend]`（すでに一部変更済み）

**対象ファイル**:
- `Core/Domain/ConnectionManager.ps1`
- `Core/Application/ConnectionManager.ps1`
- `Core/Domain/ReceivedRuleEngine.ps1`
- `Core/Domain/RuleProcessor.ps1`

### 2. コメント
**変更方針**: 新しい命名規則に統一

- 「AutoResponseプロファイル」→「OnReceiveReplyプロファイル」
- 「PeriodicSendプロファイル」→「OnTimerSendプロファイル」
- 「OnReceived」→「OnReceiveScript」

**対象ファイル**:
- `Presentation/UI/MainForm.ps1`
- `Core/Domain/ProfileService.ps1`
- その他コメント内

### 3. ローカル変数名（同じ関数内での一貫性）
**変更方針**: 同じ関数内・同じ目的の変数は統一

#### ViewBuilder.ps1/MainForm.ps1内
- `$currentOnReceivedProfile` → そのまま（OnReceiveScript列用の変数として一貫性あり）
- `$onReceivedProfiles` → そのまま（同上）
- `$currentPeriodicSendProfile` → そのまま（OnTimerSend列用として一貫性あり）
- `$periodicSendProfiles` → そのまま（同上）
- `$onReceivedRules` → そのまま（RuleProcessor内で一貫性あり）

#### Tag辞書のキー
- `OnReceivedProfileKey` → そのまま（内部識別子）
- `PeriodicSendProfileKey` → そのまま（内部識別子）

### 4. 列のName属性
**変更不要**: これらは内部識別子として固定すべき
- `"Scenario"` (On Receive: Reply列)
- `"OnReceived"` (On Receive: Script列)
- `"PeriodicSend"` (On Timer: Send列)
- `"QuickData"` (Manual: Send列)
- `"QuickAction"` (Manual: Script列)

### 5. 関数名
**変更不要**: 既存の呼び出しとの互換性のため維持
- `Start-PeriodicSend`
- `Stop-PeriodicSend`
- `Invoke-AutoResponse`
- `Invoke-BinaryAutoResponse`
- `Invoke-TextAutoResponse`

## 実装計画

### Phase 1: ログ出力の統一
1. ConnectionManager.ps1内の`[AutoResponse]`を`[OnReceiveReply]`に変更
2. RuleProcessor.ps1内のログメッセージを統一
3. ReceivedRuleEngine.ps1内のログメッセージを統一

### Phase 2: コメントの統一
1. MainForm.ps1内のコメント更新
2. ProfileService.ps1内のコメント更新
3. その他のコメント更新

### Phase 3: デバッグコード削除
- ProfileService.ps1とMainForm.ps1からデバッグ用Write-Hostを削除
