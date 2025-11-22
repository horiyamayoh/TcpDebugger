# プロファイル機能のドキュメント# プロファイル設定機能

## 概要## 概要

TCPデバッガーアプリケーションのプロファイル機能は、複数の接続に対するシナリオ設定を一括管理するための機能です。TcpDebugger のプロファイル機能を使用すると、アプリケーション起動時に各通信インスタンスのシナリオ設定を自動的に適用できます。これにより、毎回手動でシナリオを選択する手間が省け、テスト環境のセットアップを効率化できます。

## プロファイルの種類### 多層プロファイル機能（新機能）

### 1. 列プロファイル (Column Profiles)プロファイルは3つの階層で管理されます：

DataGridViewの各列（Scenario, OnReceived, PeriodicSend）に対応するプロファイルです。1. **列プロファイル（Column Profile）**
各列の上部にあるコンボボックスでプロファイルを選択すると、その列の全ての行に設定が適用されます。   - 1つのインスタンスに対する全シナリオ設定（Auto Response + On Received + Periodic）
   - コンボボックスで選択すると、3つのシナリオが一括で設定されます
#### Scenarioプロファイル   - ファイル: `Config/column_profiles/*.csv`
- 場所: `Config/scenario_profiles/`
- フォーマット: `ProfileName,ScenarioName`2. **アプリケーションプロファイル（Application Profile）**
- 例: `Config/scenario_profiles/default.csv`   - 複数インスタンスに対する列プロファイルの組み合わせ
   - 選択すると、全インスタンスの列プロファイルとシナリオが一括設定されます
```csv   - ファイル: `Config/app_profiles/*.csv`
ProfileName,ScenarioName
Default,echo_test.csv3. **個別シナリオ**
TestMode,loop_test.csv   - DataGridView の各列で個別にシナリオを選択可能
ProductionMode,echo_test.csv   - プロファイルを使わず、手動で設定することもできます
```
**使用フロー:**
選択すると、全ての接続のScenario列が指定されたシナリオファイルに設定されます。```
アプリプロファイル選択
#### OnReceivedプロファイル  ↓
- 場所: `Config/onreceived_profiles/`各インスタンスに列プロファイルが適用
- フォーマット: `ProfileName,ScenarioName`  ↓
- 例: `Config/onreceived_profiles/default.csv`各シナリオコンボボックスが自動設定
```
```csv
ProfileName,ScenarioName## 主な機能
Default,rules.csv
Debug,rules2.csv1. **インスタンスごとのシナリオ設定**
Production,rules.csv   - Auto Response シナリオの自動選択
```   - On Received シナリオの自動選択
   - Periodic シナリオの自動選択
選択すると、全ての接続のOnReceived列が指定されたシナリオファイルに設定されます。
2. **列プロファイル（新機能）**
#### Periodicプロファイル   - 3つのシナリオを1つのプロファイル名で一括管理
- 場所: `Config/periodic_profiles/`   - コンボボックスから選択するだけで全シナリオが設定される
- フォーマット: `ProfileName,ScenarioName`
- 例: `Config/periodic_profiles/default.csv`3. **アプリケーションプロファイル（新機能）**
   - 複数インスタンスの設定を1つのプロファイルで管理
```csv   - 開発環境、テスト環境、本番環境などの切り替えが容易
ProfileName,ScenarioName
Default,heartbeat.csv4. **自動接続機能**
FastHeartbeat,heartbeat2.csv   - アプリ起動時に指定したインスタンスを自動的に接続
NoHeartbeat,
```5. **プロファイルの保存と読み込み**
   - CSV 形式で設定を保存
選択すると、全ての接続のPeriodicSend列が指定されたシナリオファイルに設定されます。   - 複数のプロファイルを管理可能

### 2. アプリケーションプロファイル (Application Profiles)## プロファイルファイルの形式

アプリケーション全体の設定を一括で行うプロファイルです。### 1. 列プロファイル（Column Profile）
3つの列プロファイルを一度に設定できます。
列プロファイルは、1つのインスタンスに対する全シナリオ設定をまとめたものです。
- 場所: `Config/app_profiles/`
- フォーマット: `ProfileName,DefaultScenarioProfile,DefaultOnReceivedProfile,DefaultPeriodicProfile`**ファイルパス:** `Config/column_profiles/*.csv`
- 例: `Config/app_profiles/development.csv`
```csv
```csvProfileName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario
ProfileName,DefaultScenarioProfile,DefaultOnReceivedProfile,DefaultPeriodicProfileDefault,unified_rules.csv,rules.csv,heartbeat.csv
Development,Default,Debug,FastHeartbeatTestMode,auto_only.csv,rules2.csv,heartbeat2.csv
```ProductionMode,unified_multi_action.csv,log_login.ps1,heartbeat.csv
```
Applyボタンをクリックすると、指定された3つの列プロファイルが自動的に選択され、全ての接続に適用されます。
#### 列の説明
## 使い方
| 列名 | 必須 | 説明 |
### 列プロファイルの使用|------|------|------|
| `ProfileName` | ○ | プロファイル名（コンボボックスに表示される） |
1. DataGridViewの上部にある各列のプロファイルコンボボックスを確認| `AutoResponseScenario` | × | Auto Response シナリオファイル名 |
   - Scenario Profile: Auto Response列用| `OnReceivedScenario` | × | On Received シナリオファイル名 |
   - OnReceived Profile: On Received列用| `PeriodicScenario` | × | Periodic シナリオファイル名 |
   - Periodic Profile: Periodic Send列用
**使い方:**
2. プロファイルを選択1. GUIの「Column Profile」コンボボックスから選択
   - コンボボックスから希望するプロファイルを選択2. 選択したインスタンスの3つのシナリオが一括で設定される
   - 選択すると即座に全ての接続の該当列に設定が適用される3. 複数の列プロファイルを定義して、用途に応じて切り替え可能

### アプリケーションプロファイルの使用### 2. アプリケーションプロファイル（Application Profile）

1. 右上の「App Profile」コンボボックスからプロファイルを選択アプリケーションプロファイルは、複数インスタンスの設定をまとめたものです。

2. 「Apply」ボタンをクリック**ファイルパス:** `Config/app_profiles/*.csv`

3. 選択されたプロファイルに基づいて、3つの列プロファイルコンボボックスが自動的に設定される```csv
InstanceName,ColumnProfileName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario,AutoConnect
4. それぞれの列プロファイルが全ての接続に適用されるExample,Default,,,,false
```
## ファイル構成
#### 列の説明
```
Config/| 列名 | 必須 | 説明 |
  ├── scenario_profiles/|------|------|------|
  │   └── default.csv        (Scenario列用プロファイル)| `InstanceName` | ○ | インスタンス名 |
  ├── onreceived_profiles/| `ColumnProfileName` | × | 使用する列プロファイル名 |
  │   └── default.csv        (OnReceived列用プロファイル)| `AutoResponseScenario` | × | Auto Response シナリオ（ColumnProfileName が空の場合） |
  ├── periodic_profiles/| `OnReceivedScenario` | × | On Received シナリオ（ColumnProfileName が空の場合） |
  │   └── default.csv        (Periodic列用プロファイル)| `PeriodicScenario` | × | Periodic シナリオ（ColumnProfileName が空の場合） |
  └── app_profiles/| `AutoConnect` | × | 起動時に自動接続するか（`true`/`false`） |
      ├── development.csv    (開発環境用設定)
      └── production.csv     (本番環境用設定)**優先順位:**
```- `ColumnProfileName` が指定されている場合、そのプロファイルが適用される
- `ColumnProfileName` が空の場合、個別のシナリオ列が使用される
## プロファイルの作成- 両方指定されている場合、`ColumnProfileName` が優先される

### 列プロファイルの作成**使い方:**
1. GUIの「App Profile」コンボボックスから選択
1. 該当するディレクトリに新しいCSVファイルを作成2. 「Apply Profile」ボタンをクリック
   - Scenario用: `Config/scenario_profiles/myprofile.csv`3. 全インスタンスに設定が一括適用される
   - OnReceived用: `Config/onreceived_profiles/myprofile.csv`
   - Periodic用: `Config/periodic_profiles/myprofile.csv`### 3. 従来型プロファイル（下位互換）

2. CSVフォーマットに従って設定を記述従来型の個別シナリオ指定も引き続き使用可能です。

```csv**ファイルパス:** `Config/profiles.csv`
ProfileName,ScenarioName
MyProfile,my_scenario.csv```csv
```InstanceName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario,AutoConnect
Example,unified_rules.csv,rules.csv,heartbeat.csv,false
3. アプリケーションを再起動すると、コンボボックスに新しいプロファイルが表示される```

### アプリケーションプロファイルの作成### シナリオファイル名の指定方法

1. `Config/app_profiles/` に新しいCSVファイルを作成- 拡張子（`.csv` または `.ps1`）は含めても省略しても構いません
  - 例: `unified_rules` または `unified_rules.csv` のどちらでも可
2. 3つの列プロファイル名を指定- シナリオを使用しない場合は、空欄にします
- 相対パスは、各シナリオタイプの標準フォルダからの相対パスになります
```csv
ProfileName,DefaultScenarioProfile,DefaultOnReceivedProfile,DefaultPeriodicProfile## デフォルトプロファイルの設定
MyAppProfile,MyScenarioProfile,MyOnReceivedProfile,MyPeriodicProfile
```アプリケーション起動時に自動的に読み込まれるプロファイルは、以下のパスに配置します：

3. アプリケーションを再起動すると、コンボボックスに新しいプロファイルが表示される```
Config/profiles.csv
## 注意事項```

- プロファイル名（ファイル名の拡張子を除いた部分）がコンボボックスに表示されますこのファイルが存在する場合、アプリ起動時に自動的に読み込まれ、各インスタンスに設定が適用されます。
- CSVファイルはUTF-8エンコーディングで保存してください
- ScenarioNameが空の場合、その列には何も設定されません## インスタンス専用プロファイル
- 存在しないシナリオファイルを指定すると、エラーメッセージが表示されます
- プロファイルの選択は即座に適用されますが、実際の接続動作には影響しません（接続を再起動する必要はありません）各インスタンスフォルダ内に `profile.csv` を配置することもできます：

```
Instances/Example/profile.csv
```
このファイルは、そのインスタンス専用の設定として使用できます（将来の拡張用）。
## 使用例
### 例1: 列プロファイルの使用
**Config/column_profiles/default.csv**
```csv
ProfileName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario
Default,unified_rules.csv,rules.csv,heartbeat.csv
TestMode,auto_only.csv,rules2.csv,heartbeat2.csv
```
**操作手順:**
1. GUIでインスタンスを選択
2. 「Column Profile」コンボボックスから「Default」を選択
3. 3つのシナリオが自動的に設定される
### 例2: アプリケーションプロファイルの使用
**Config/app_profiles/development.csv**
```csv
InstanceName,ColumnProfileName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario,AutoConnect
Server1,Default,,,,false
Client1,TestMode,,,,false
```
**操作手順:**
1. 「App Profile」コンボボックスから「development」を選択
2. 「Apply Profile」ボタンをクリック
3. Server1に「Default」列プロファイルが適用される
4. Client1に「TestMode」列プロファイルが適用される
### 例3: 列プロファイルと個別シナリオの混在
**Config/app_profiles/mixed.csv**
```csv
InstanceName,ColumnProfileName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario,AutoConnect
Server1,Default,,,,true
Client1,,auto_only.csv,log_login.ps1,heartbeat2.csv,false
```
- `Server1`: 「Default」列プロファイルを使用、起動時に自動接続
- `Client1`: 列プロファイルを使わず、個別にシナリオを指定
### 例4: 本番環境と開発環境の切り替え
**Config/column_profiles/default.csv**
```csv
ProfileName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario
Development,unified_rules.csv,rules.csv,heartbeat.csv
Production,unified_multi_action.csv,log_login.ps1,heartbeat.csv
```
**Config/app_profiles/production.csv**
```csv
InstanceName,ColumnProfileName,AutoResponseScenario,OnReceivedScenario,PeriodicScenario,AutoConnect
Example,Production,,,,true
```
**操作手順:**
- 開発時: 「Column Profile」で「Development」を選択
- 本番時: 「App Profile」で「production」を選択 → 「Apply Profile」をクリック
## プロファイルの動作フロー
1. **アプリケーション起動**
   - `Config/profiles.csv` が存在するか確認
2. **プロファイル読み込み**
   - CSV ファイルを解析し、各インスタンスの設定を読み込む
3. **シナリオ適用**
   - 各インスタンスに対して、指定されたシナリオファイルのパスを解決
   - シナリオファイルが存在する場合、接続に設定を適用
4. **自動接続**
   - `AutoConnect` が `true` のインスタンスを順次接続
5. **UI 更新**
   - DataGridView を更新し、適用された設定を表示
## シナリオファイルのパス解決
システムは以下の順序でシナリオファイルを検索します：
1. **完全パス**: 指定されたパスがそのまま存在するか確認
2. **拡張子付与**: `.csv` 拡張子を追加して確認
3. **スクリプト拡張子**: `.ps1` 拡張子を追加して確認（On Received のみ）
例:
- `unified_rules` と指定した場合
  - `scenarios/auto/unified_rules` → 存在しない
  - `scenarios/auto/unified_rules.csv` → 存在すれば使用
  - `scenarios/auto/unified_rules.ps1` → 存在すれば使用
## エラー処理
### プロファイルが読み込めない場合
- 警告メッセージを表示し、処理を続行
- インスタンスは手動で設定可能な状態で起動
### シナリオファイルが見つからない場合
- 警告ログを出力し、そのシナリオはスキップ
- 他のシナリオは正常に適用
### 自動接続に失敗した場合
- エラーログを出力し、次のインスタンスへ進む
- 手動で接続することは可能
## プロファイルの管理
### プロファイルファイルの作成
1. テンプレートをコピー:
   ```powershell
   Copy-Item Config\profiles.csv Config\profiles_backup.csv
   ```
2. エディタで編集（CSV 形式を維持）
3. アプリを再起動して適用を確認
### 複数プロファイルの管理
異なる環境や用途に応じて、複数のプロファイルファイルを用意できます：
```
Config/
  profiles.csv           # デフォルト（開発環境）
  profiles_test.csv      # テスト環境
  profiles_production.csv # 本番環境
```
使用するプロファイルを `profiles.csv` にコピーして使用します。
## ベストプラクティス
1. **バージョン管理**
   - プロファイルファイルを Git などで管理
   - チーム間で設定を共有
2. **命名規則**
   - シナリオファイル名は分かりやすい名前を使用
   - インスタンス名とシナリオ名の対応を明確にする
3. **段階的な適用**
   - 新しいプロファイルは、まず `AutoConnect=false` でテスト
   - 動作確認後、必要に応じて自動接続を有効化
4. **ドキュメント化**
   - 各プロファイルの用途をコメント（CSV の先頭行に `#` で記載）
   - README などで設定の意図を説明
## トラブルシューティング
### シナリオが適用されない
**原因と対処:**
- ファイルパスが正しいか確認（大文字小文字を含む）
- シナリオファイルが実際に存在するか確認
- ログ出力を確認（`[Init]` タグ付きメッセージ）
### 自動接続が失敗する
**原因と対処:**
- 接続先サーバーが起動しているか確認
- インスタンス設定（`instance.psd1`）が正しいか確認
- 手動接続を試して、エラーメッセージを確認
### プロファイルが読み込まれない
**原因と対処:**
- `Config/profiles.csv` が存在するか確認
- CSV 形式が正しいか確認（列名のスペルミス等）
- 文字エンコーディングが UTF-8 であることを確認
## 今後の拡張予定
- UI からのプロファイル編集機能
- プロファイルの切り替え機能（再起動不要）
- プロファイルの自動保存機能
- より詳細な設定項目の追加
## 関連ファイル
- `Core/Domain/ProfileModels.ps1` - プロファイルのデータモデル
- `Core/Domain/ProfileService.ps1` - プロファイル管理ロジック
- `Core/Infrastructure/Repositories/ProfileRepository.ps1` - CSV 読み書き処理
- `Config/profiles.csv` - デフォルトプロファイル
- `Instances/Example/profile.csv` - インスタンス専用プロファイル例
