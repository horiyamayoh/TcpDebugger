# 受信ルール共通フォーマット仕様

## 概要
On Receive: Reply機能とOn Receive: Script機能は、それぞれ独立したCSVルールファイルを使用します。
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

### On Receive: Reply専用列
| 列名 | 必須 | 説明 |
|------|------|------|
| ResponseMessageFile | 必須 | 応答電文CSVファイル名（相対パスまたは絶対パス）<br>相対パスの場合は `templates/` からの相対パス |

### On Receive: Script専用列
| 列名 | 必須 | 説明 |
|------|------|------|
| ScriptFile | 必須 | 実行するPowerShellスクリプトファイル名（相対パスまたは絶対パス）<br>相対パスの場合は `scenarios/on_receive_script/` からの相対パス |
| ExecutionTiming | 任意 | スクリプト実行タイミング<br>`Before`: On Receive: Replyの前に実行<br>`After`: On Receive: Replyの後に実行（デフォルト） |

## ルールタイプの自動判定

CSVファイルを読み込む際、以下のロジックでルールタイプを判定します:

1. `ResponseMessageFile` 列が存在 → **On Receive: Replyルール**
2. `ScriptFile` 列が存在 → **On Receive: Scriptルール**
3. `TriggerPattern` 列が存在 → **旧形式On Receive: Replyルール**（後方互換性のため維持）

## ファイル構成

On Receive: ReplyとOn Receive: Scriptは**別々のCSVファイル**で管理します。

### On Receive: Replyルールの例
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ResponseMessageFile,Delay
応答01,0,2,0102,response_01.csv,0
応答02,0,2,0103,response_02.csv,100
エラー応答,0,2,0199,error_response.csv,0
```

### On Receive: Scriptルールの例
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ScriptFile,Delay,ExecutionTiming
ID転記,0,2,0102,copy_message_id.ps1,0,Before
シーケンス処理,0,2,0103,process_sequence.ps1,0,Before
エコーバック,0,2,0104,echo_back.ps1,0,After
```

### ExecutionTimingの使い分け
- **`Before`**: On Receive: Reply実行前にスクリプトを実行
  - 用途: スクリプトで処理した結果を応答に含めたい場合
  - 例: データベースへの書き込み結果を応答に反映、変数の更新など
- **`After`** (デフォルト): On Receive: Reply実行後にスクリプトを実行
  - 用途: 応答を優先し、バッチ処理は後で行う場合
  - 例: ログ記録、統計更新など、応答に影響しない処理

## 処理順序

同一の受信電文に対して、以下の順序で処理されます：

1. **Before OnReceiveScript**: `ExecutionTiming=Before`のOnReceiveScriptスクリプトを実行
2. **OnReceiveReply**: 自動応答電文を送信
3. **After OnReceiveScript**: `ExecutionTiming=After`のOnReceiveScriptスクリプトを実行（デフォルト）

各カテゴリ内で複数のルールがマッチした場合、CSV記載順に**すべて実行**されます。

## マッチング動作

### 複数ルールの処理
- CSVファイル内のルールは**上から順に評価**されます
- マッチしたルールは**すべて実行**されます（最初の1件だけではありません）
- 同一の電文に対して複数のルールを定義することで、複数のアクションを順次実行できます

### 実行例
OnReceiveReplyルールとOnReceiveScriptルールの両方が設定されている場合：

**OnReceiveReplyルール (reply_rules.csv):**
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ResponseMessageFile,Delay
ログイン応答,0,2,0001,login_response.csv,0
```

**OnReceiveScriptルール (script_rules.csv):**
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ScriptFile,Delay,ExecutionTiming
ログイン前処理,0,2,0001,pre_login.ps1,0,Before
ログイン後処理,0,2,0001,post_login.ps1,0,After
```

**電文 `0001...` を受信した場合の実行順序:**
1. `pre_login.ps1` を実行（Before）
2. `login_response.csv` を送信（OnReceiveReply）
3. `post_login.ps1` を実行（After）

### バイナリマッチング（新形式）
- `MatchOffset`, `MatchLength`, `MatchValue` を使用
- 受信データの指定位置のバイト列と16進数値を比較
- すべて一致した場合にルールが適用される

### マッチング省略
- `MatchOffset` を省略または空欄にした場合、すべての受信データにマッチ
- この場合、最初に定義されたルールのみが実行される

### テキストマッチング（旧形式On Receive: Reply）
- `TriggerPattern` を使用（後方互換性のため維持）
- `MatchType` で比較方法を指定（Exact/Contains/StartsWith/EndsWith/Regex）

## エンコーディング
- CSVファイルは **UTF-8** エンコーディングで保存すること
- 電文CSVファイルも同様にUTF-8

## ファイル配置
```
Instances/
  {InstanceName}/
    scenarios/
      on_receive_reply/
        binary_rules.csv          # OnReceiveReplyルール
      on_receive_script/
        rules.csv                  # OnReceiveScriptルール
        copy_message_id.ps1        # OnReceiveScriptスクリプト
        process_sequence.ps1
    templates/
      response_01.csv              # OnReceiveReply応答電文
      response_02.csv
      response_with_id.csv         # OnReceiveScriptで使用する電文
      sequence_response.csv
```

## 使用例

### 複数の応答パターン（OnReceiveReply）
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ResponseMessageFile,Delay
ログイン応答,0,2,0001,login_response.csv,0
ログアウト応答,0,2,0002,logout_response.csv,0
データ要求応答,0,2,0010,data_response.csv,50
```

### 複数の処理（OnReceiveScript）
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ScriptFile,Delay,ExecutionTiming
ログイン処理,0,2,0001,handle_login.ps1,0,Before
データ保存,0,2,0010,save_data.ps1,0,After
状態更新,0,2,0020,update_state.ps1,0,After
```

## 注意事項

1. **ファイル分離**: OnReceiveReplyとOnReceiveScriptは別々のCSVファイルで管理
2. **ルールの評価順序**: 各CSVファイル内で上から順に評価され、マッチしたルールは**すべて**実行される
3. **処理順序**: Before OnReceiveScript → OnReceiveReply → After OnReceiveScript の順に実行
4. **16進数値**: `MatchValue` は16進数文字列（0-9A-Fa-f）で記述、スペース・ハイフン不可
5. **長さの整合性**: `MatchValue` のバイト数（文字数÷2）と `MatchLength` は一致する必要がある
6. **大文字小文字**: 16進数値は大文字・小文字どちらでも可
7. **相対パス**: `ResponseMessageFile` や `ScriptFile` で相対パスを使用する場合、インスタンスフォルダからの相対パス
8. **遅延の累積**: 複数ルールがマッチした場合、各ルールの `Delay` は個別に適用される（累積する）

## 使用上のヒント

### 同一電文への複数処理（OnReceiveScript）
```csv
RuleName,MatchOffset,MatchLength,MatchValue,ScriptFile,Delay,ExecutionTiming
処理1-即座,0,2,0001,process1.ps1,0,After
処理2-100ms後,0,2,0001,process2.ps1,100,After
処理3-200ms後,0,2,0001,process3.ps1,200,After
```
この例では、応答送信 → 即座に処理1 → 100ms後に処理2 → 200ms後に処理3が順次実行されます。

