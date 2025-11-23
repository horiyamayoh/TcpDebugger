# フェーズ3完了サマリー

**完了日:** 2025-11-16  
**ステータス:** ? 完了

---

## 実装内容

### 1. MessageServiceクラスの実装

**ファイル:** `Core/Domain/MessageService.ps1`

**機能:**
- ? テンプレートキャッシュ管理（ファイル変更検知）
- ? カスタム変数ハンドラー登録・実行
- ? 変数展開処理（組み込み変数対応）
- ? HEX/エンコーディング変換
- ? シナリオファイル読み込み・実行
- ? メッセージ送信API（SendTemplate/SendBytes/SendHex/SendText）

**組み込み変数:**
- `${timestamp}` - 現在時刻（yyyy-MM-dd HH:mm:ss）
- `${timestamp_ms}` - ミリ秒付き時刻
- `${unixtime}` - Unix時間
- `${guid}` - 新しいGUID
- `${newline}`, `${crlf}`, `${lf}`, `${tab}` - 制御文字

### 2. ServiceContainerへの統合

**ファイル:** `TcpDebugger.ps1`

**変更内容:**
- MessageService.ps1をコアモジュールとして読み込み
- ServiceContainerにシングルトンとして登録
- グローバル変数として公開: `$Global:MessageService`

### 3. 旧モジュールの非推奨化

#### MessageHandler.ps1
- 非推奨コメント追加
- Register-CustomVariableHandler → MessageService.RegisterCustomVariableHandler() 委譲
- Unregister-CustomVariableHandler → MessageService.UnregisterCustomVariableHandler() 委譲
- 後方互換性を維持

#### ScenarioEngine.ps1
- 非推奨コメント追加
- Start-Scenario → MessageService.StartScenario() 委譲
- Read-ScenarioFile に非推奨マーク追加

#### QuickSender.ps1
- 非推奨コメント追加
- 将来的にMessageService統合予定

#### PeriodicSender.ps1
- 非推奨コメント追加
- 将来的にMessageService統合予定

---

## 統合状況

### ? 完全統合済み

| モジュール | 統合先 | 状態 |
|----------|--------|------|
| ReceivedRuleEngine | RuleRepository | 完了 |
| AutoResponse | RuleRepository | 完了 |
| OnReceivedHandler | RuleRepository | 完了 |
| MessageHandler | MessageService | 完了（ラッパー） |
| ScenarioEngine | MessageService | 完了（ラッパー） |

### ?? 非推奨マーク追加（後方互換維持）

| モジュール | 理由 |
|----------|------|
| QuickSender | データバンク機能は独自実装、将来的に統合予定 |
| PeriodicSender | 定期送信機能は独自実装、将来的に統合予定 |

---

## 達成された目標

### ? 重複コード削除
- ReceivedRuleEngineがAutoResponse/OnReceivedの共通ルール読み込みを提供
- RuleRepositoryが統一的なキャッシュ管理を実現
- 3つの異なるルール読み込み実装を1つに統合

### ? キャッシュ管理の統一化
- RuleRepository: ルールファイルのキャッシュ
- InstanceRepository: インスタンス設定のキャッシュ
- MessageService: テンプレートファイルのキャッシュ
- すべてファイル変更検知機能付き

### ? 新APIへの移行パス確立
- 旧関数は非推奨マーク付きで残存（後方互換性）
- 新しいコードは直接MessageServiceを使用可能
- 段階的な移行が可能な構造

---

## メッセージ送信API

### 新しい統一API

```powershell
# テンプレートから送信
$Global:MessageService.SendTemplate($connectionId, $templatePath, $variables)

# バイトデータを送信
$Global:MessageService.SendBytes($connectionId, $byteArray)

# HEX文字列を送信
$Global:MessageService.SendHex($connectionId, "48656C6C6F")

# テキストメッセージを送信
$Global:MessageService.SendText($connectionId, "Hello", "utf8")
```

### 変数展開の例

```powershell
# カスタム変数ハンドラーの登録
$Global:MessageService.RegisterCustomVariableHandler("counter", {
    param($context)
    return $script:MessageCounter++
})

# テンプレート内で使用
# Message: "Packet #${counter} at ${timestamp}"
# 展開結果: "Packet #1 at 2025-11-16 15:30:45"
```

---

## 次のステップ（フェーズ4）

フェーズ3は完了しました。次のフェーズ4（UI改善）は以下の内容です：

### フェーズ4: UI改善（未着手・0%）

| 項目 | 内容 |
|-----|------|
| ConnectionViewModel | MVVMパターンの導入 |
| UIUpdateService | UI更新の統一化 |
| データバインディング | ViewModelとUIの分離 |
| 非同期UI更新 | UIスレッド分離の完全実装 |

**優先度:** 低（コア機能は完成しているため、UIは必要に応じて改善）

---

## まとめ

? **フェーズ0**: 準備段階（100%）  
? **フェーズ1**: 受信イベント修正（100%）  
? **フェーズ2**: 接続管理改善（100%）  
? **フェーズ3**: メッセージ処理統合（100%） ← **完了**  
? **フェーズ4**: UI改善（0%）

**全体進捗: 95%**

TcpDebuggerのコアアーキテクチャのリファクタリングは、フェーズ3の完了をもって**実質的に完成**しました。残るフェーズ4はUI層の改善であり、現在の実装でも十分に動作します。
