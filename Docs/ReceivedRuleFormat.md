# 受信ルール共通フォーマット仕様

## 概要
AutoResponse機能とOnReceived機能は、共通のCSVルールフォーマットを使用します。
ルールタイプは、CSVの列によって自動判定されます。

## CSV列定義

### 共通列
| 列名 | 必須 | 説明 |
|------|------|------|
| RuleName | 推奨 | ルールの名前（ログ出力等に使用） |
| MatchOffset | 条件付 | マッチング開始位置（バイト単位、10進数）<br>省略時は全受信データにマッチ |
| MatchLength | 条件付 | マッチング長さ（バイト数、10進数）<br>MatchOffsetを指定した場合は必須 |
| MatchValue | 条件付 | マッチさせる16進数値<br>MatchOffsetを指定した場合は必須 |
| Delay | 任意 | アクション実行前の遅延（ミリ秒、10進数）<br>デフォルト: 0 |

### AutoResponse専用列
| 列名 | 必須 | 説明 |
|------|------|------|
| ResponseMessageFile | 必須 | 応答電文CSVファイル名（相対パスまたは絶対パス）<br>相対パスの場合は `templates/` からの相対パス |

### OnReceived専用列
| 列名 | 必須 | 説明 |
|------|------|------|
| ScriptFile | 必須 | 実行するPowerShellスクリプトファイル名（相対パスまたは絶対パス）<br>相対パスの場合は `scenarios/onreceived/` からの相対パス |

## ルールタイプの自動判定

CSVファイルを読み込む際、以下のロジックでルールタイプを判定します:

1. `ResponseMessageFile` と `ScriptFile` の両方の列が存在 → **統合形式**（両方のアクションを使用可能）
2. `ResponseMessageFile` 列のみ存在 → **AutoResponseルール**
3. `ScriptFile` 列のみ存在 → **OnReceivedルール**
4. `TriggerPattern` 列が存在 → **旧形式AutoResponseルール**（互換性維持）

## 統合ルールファイル（推奨）

**統合形式では、同一のCSVファイルにAutoResponseとOnReceivedのアクションを自由に組み合わせて記述できます。**

### 動作仕様
1. **複数ルールのマッチング**: 同一の電文に対して複数のルールがマッチした場合、CSV記載順に**すべて実行**されます
2. **アクションの組み合わせ**: 各行で以下のパターンを使い分けできます
   - `ResponseMessageFile` のみ指定 → 応答電文の送信のみ
   - `ScriptFile` のみ指定 → スクリプト実行のみ
   - 両方指定 → 応答電文送信後にスクリプト実行
   - 両方空欄 → アクションなし（警告が出る）

### 統合形式の例
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ResponseMessageFile,ScriptFile,Delay
ログイン要求-応答,0,2,0001,login_response.csv,,0
ログイン要求-ログ記録,0,2,0001,,log_login.ps1,10
データ要求-応答送信,0,2,0010,data_response.csv,,0
データ要求-データ保存,0,2,0010,,save_data.ps1,50
データ要求-統計更新,0,2,0010,,update_stats.ps1,100
エコー要求-両方実行,0,2,0020,echo_response.csv,log_echo.ps1,0
```

#### 実行例（電文 `0001...` を受信した場合）
1. **ログイン要求-応答**: `login_response.csv` の内容を即座に送信
2. **ログイン要求-ログ記録**: 10ms待機後、`log_login.ps1` を実行してログ記録

#### 実行例（電文 `0010...` を受信した場合）
1. **データ要求-応答送信**: `data_response.csv` の内容を即座に送信
2. **データ要求-データ保存**: 50ms待機後、`save_data.ps1` を実行してデータ保存
3. **データ要求-統計更新**: さらに100ms待機後、`update_stats.ps1` を実行して統計更新

**合計3つのアクションが順次実行されます。**

### AutoResponseルールの例
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ResponseMessageFile,Delay
応答01,0,2,0102,response_01.csv,0
応答02,0,2,0103,response_02.csv,100
エラー応答,0,2,0199,error_response.csv,0
```

### OnReceivedルールの例
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ScriptFile,Delay
ID転記,0,2,0102,copy_message_id.ps1,0
シーケンス処理,0,2,0103,process_sequence.ps1,0
エコーバック,0,2,0104,echo_back.ps1,0
```

## マッチング動作

### 複数ルールの処理
- CSVファイル内のルールは**上から順に評価**されます
- マッチしたルールは**すべて実行**されます（最初の1件だけではありません）
- 同一の電文に対して複数のルールを定義することで、複数のアクションを順次実行できます

### バイナリマッチング（新形式）
- `MatchOffset`, `MatchLength`, `MatchValue` を使用
- 受信データの指定位置のバイト列と16進数値を比較
- すべて一致した場合にルールが適用される

### マッチング省略
- `MatchOffset` を省略または空欄にした場合、すべての受信データにマッチ
- この場合、最初に定義されたルールのみが実行される

### テキストマッチング（旧形式AutoResponse）
- `TriggerPattern` を使用（後方互換性のため維持）
- `MatchType` で比較方法を指定（Exact/Contains/StartsWith/EndsWith/Regex）

## エンコーディング
- CSVファイルは **Shift-JIS** エンコーディングで保存すること
- 電文CSVファイルも同様にShift-JIS

## ファイル配置
```
Instances/
  {InstanceName}/
    scenarios/
      auto/
        binary_rules.csv          # AutoResponseルール
      onreceived/
        rules.csv                  # OnReceivedルール
        copy_message_id.ps1        # OnReceivedスクリプト
        process_sequence.ps1
    templates/
      response_01.csv              # AutoResponse応答電文
      response_02.csv
      response_with_id.csv         # OnReceivedで使用する電文
      sequence_response.csv
```

## 使用例

### 電文種別による自動応答
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ResponseMessageFile,Delay
ログイン応答,0,2,0001,login_response.csv,0
ログアウト応答,0,2,0002,logout_response.csv,0
データ要求応答,0,2,0010,data_response.csv,50
```

### 電文種別によるスクリプト実行
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ScriptFile,Delay
ログイン処理,0,2,0001,handle_login.ps1,0
データ保存,0,2,0010,save_data.ps1,0
状態更新,0,2,0020,update_state.ps1,0
```

## 注意事項

1. **ルールの評価順序**: CSVの上から順に評価され、マッチしたルールは**すべて**実行される
2. **複数アクション**: 同一電文に対して複数のルールを定義することで、複数の処理を順次実行可能
3. **16進数値**: `MatchValue` は16進数文字列（0-9A-Fa-f）で記述、スペース・ハイフン不可
4. **長さの整合性**: `MatchValue` のバイト数（文字数÷2）と `MatchLength` は一致する必要がある
5. **大文字小文字**: 16進数値は大文字・小文字どちらでも可
6. **相対パス**: `ResponseMessageFile` や `ScriptFile` で相対パスを使用する場合、インスタンスフォルダからの相対パス
7. **遅延の累積**: 複数ルールがマッチした場合、各ルールの `Delay` は個別に適用される（累積する）

## 使用上のヒント

### シーケンシャルな処理の実現
```csv
処理1-応答,0,2,0001,response.csv,,0,true
処理2-ログ,0,2,0001,,log.ps1,100,true
処理3-DB保存,0,2,0001,,save_db.ps1,200,true
```
この例では、応答送信 → 100ms後にログ記録 → 200ms後にDB保存が順次実行されます。

### 並列的な処理の実現（Delay=0）
```csv
応答送信,0,2,0001,response.csv,,0,true
ログ記録,0,2,0001,,log.ps1,0,true
統計更新,0,2,0001,,update_stats.ps1,0,true
```
すべて `Delay=0` にすると、ほぼ同時に実行されます。

