# Pester 3.x 対応ガイド

## 概要

Windows PowerShell 5.1に標準搭載されているPester 3.4.0に対応するための構文変更ガイドです。

## Pester 3.x と 5.x の主な違い

### 1. Should アサーション構文

| Pester 5.x | Pester 3.x |
|------------|------------|
| `Should -Be` | `Should Be` |
| `Should -Not -Be` | `Should Not Be` |
| `Should -BeNullOrEmpty` | `Should BeNullOrEmpty` |
| `Should -Not -BeNullOrEmpty` | `Should Not BeNullOrEmpty` |
| `Should -Throw` | `Should Throw` |
| `Should -Not -Throw` | `Should Not Throw` |
| `Should -BeOfType` | `Should BeOfType` |
| `Should -Match` | `Should Match` |
| `Should -Contain` | `Should Contain` |

### 2. BeforeAll/AfterAll ブロック

```powershell
# ❌ Pester 5.x（Pester 3.xではエラー）
BeforeAll {
    # グローバルスコープでの初期化
    $script:Logger = [Logger]::new()
}

Describe "Tests" {
    # ...
}

# ✅ Pester 3.x（Describeの外で実行）
# テスト対象モジュールをロード
. "$PSScriptRoot\..\..\Module.ps1"

Describe "Tests" {
    BeforeEach {
        # 各テストケースごとの初期化
        $script:Logger = [Logger]::new()
    }
    # ...
}
```

### 3. TestCases パラメータ

```powershell
# ❌ Pester 5.x
It "should validate <Value>" -TestCases @(
    @{ Value = 1 }
    @{ Value = 2 }
) {
    param($Value)
    $Value | Should -BeGreaterThan 0
}

# ✅ Pester 3.x
@(1, 2) | ForEach-Object {
    $testValue = $_
    It "should validate $testValue" {
        $testValue | Should BeGreaterThan 0
    }
}
```

## ConnectionService.Tests.ps1 の修正例

### 修正前（Pester 5.x）

```powershell
BeforeAll {
    $rootPath = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
    . "$rootPath\Core\Common\Logger.ps1"
    . "$rootPath\Core\Common\Exceptions.ps1"
    . "$rootPath\Core\Domain\VariableScope.ps1"
    . "$rootPath\Core\Domain\ConnectionModels.ps1"
    . "$rootPath\Core\Domain\ConnectionService.ps1"
}

Describe "ConnectionService" {
    BeforeEach {
        $script:TestLogger = [Logger]::new("TestDrive:\test.log", "TestLogger", 10, 5, $false)
        $script:TestStore = [System.Collections.Hashtable]::Synchronized(@{})
        $script:Service = [ConnectionService]::new($script:TestLogger, $script:TestStore)
    }
    
    Context "AddConnection" {
        It "新しい接続を追加できる" {
            $config = @{
                Id = "test-conn-1"
                Name = "TestConnection"
                Protocol = "TCP"
            }
            
            $connection = $script:Service.AddConnection($config)
            
            $connection | Should -Not -BeNullOrEmpty
            $connection.Id | Should -Be "test-conn-1"
        }
    }
}
```

### 修正後（Pester 3.x）

```powershell
# テスト対象モジュールをロード（Describeの外）
$rootPath = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
. "$rootPath\Core\Common\Logger.ps1"
. "$rootPath\Core\Common\Exceptions.ps1"
. "$rootPath\Core\Domain\VariableScope.ps1"
. "$rootPath\Core\Domain\ConnectionModels.ps1"
. "$rootPath\Core\Domain\ConnectionService.ps1"

Describe "ConnectionService" {
    BeforeEach {
        # 各テストケースの前に実行
        $script:TestLogger = [Logger]::new("TestDrive:\test.log", "TestLogger", 10, 5, $false)
        $script:TestStore = [System.Collections.Hashtable]::Synchronized(@{})
        $script:Service = [ConnectionService]::new($script:TestLogger, $script:TestStore)
    }
    
    Context "AddConnection" {
        It "新しい接続を追加できる" {
            # Arrange
            $config = @{
                Id = "test-conn-1"
                Name = "TestConnection"
                Protocol = "TCP"
            }
            
            # Act
            $connection = $script:Service.AddConnection($config)
            
            # Assert
            $connection | Should Not BeNullOrEmpty
            $connection.Id | Should Be "test-conn-1"
        }
        
        It "設定がnullの場合は例外をスローする" {
            # Act & Assert
            { $script:Service.AddConnection($null) } | Should Throw
        }
    }
    
    Context "GetConnection" {
        It "存在する接続IDで接続を取得できる" {
            # Arrange
            $config = @{
                Id = "test-conn-1"
                Name = "TestConnection"
                Protocol = "TCP"
            }
            $script:Service.AddConnection($config)
            
            # Act
            $connection = $script:Service.GetConnection("test-conn-1")
            
            # Assert
            $connection | Should Not BeNullOrEmpty
            $connection.Id | Should Be "test-conn-1"
        }
        
        It "存在しない接続IDの場合はnullを返す" {
            # Act
            $connection = $script:Service.GetConnection("non-existent")
            
            # Assert
            $connection | Should BeNullOrEmpty
        }
    }
    
    Context "RemoveConnection" {
        It "存在する接続を削除できる" {
            # Arrange
            $config = @{
                Id = "test-conn-1"
                Name = "TestConnection"
                Protocol = "TCP"
            }
            $script:Service.AddConnection($config)
            
            # Act
            $script:Service.RemoveConnection("test-conn-1")
            
            # Assert
            $connection = $script:Service.GetConnection("test-conn-1")
            $connection | Should BeNullOrEmpty
        }
        
        It "存在しない接続IDでも例外をスローしない" {
            # Act & Assert
            { $script:Service.RemoveConnection("non-existent") } | Should Not Throw
        }
    }
}
```

## よくあるエラーと対処法

### エラー1: "is not a valid Should operator"

```
RuntimeException: '-Not' is not a valid Should operator.
```

**原因:** Pester 5.x構文を使用している

**対処法:** ハイフンを削除

```powershell
# Before
$value | Should -Not -BeNullOrEmpty

# After
$value | Should Not BeNullOrEmpty
```

### エラー2: "BeforeAll command may only be used inside a Describe block"

```
RuntimeException: The BeforeAll command may only be used inside a Describe block.
```

**原因:** Pester 3.xではBeforeAllがサポートされていない

**対処法:** Describeブロックの外でモジュールをロード

```powershell
# Before
BeforeAll {
    . "$PSScriptRoot\Module.ps1"
}

Describe "Tests" { }

# After
. "$PSScriptRoot\Module.ps1"

Describe "Tests" { }
```

### エラー3: TestCases not supported

```
RuntimeException: A parameter cannot be found that matches parameter name 'TestCases'.
```

**原因:** Pester 3.xはTestCasesパラメータをサポートしていない

**対処法:** ForEach-Objectを使用

```powershell
# Before
It "should validate <Value>" -TestCases @(
    @{ Value = 1 }
    @{ Value = 2 }
) {
    param($Value)
    $Value | Should -Be 1
}

# After
@(1, 2) | ForEach-Object {
    $testValue = $_
    It "should validate $testValue" {
        $testValue | Should Be $testValue
    }
}
```

## テスト実行方法

### Pester 3.x でテストを実行

```powershell
# 特定のテストファイルを実行
Invoke-Pester -Path "Tests\Unit\Core\Domain\ConnectionService.Tests.ps1"

# すべてのテストを実行
Invoke-Pester -Path "Tests\Unit"

# 詳細出力
Invoke-Pester -Path "Tests\Unit" -Verbose
```

### テスト結果の例

```
Describing ConnectionService
 Context AddConnection
  [+] 新しい接続を追加できる 123ms
  [+] 設定がnullの場合は例外をスローする 45ms
 Context GetConnection
  [+] 存在する接続IDで接続を取得できる 67ms
  [+] 存在しない接続IDの場合はnullを返す 23ms

Tests completed in 258ms
Passed: 4 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0
```

## アサーション一覧

### 基本的なアサーション

```powershell
# 等価性
$value | Should Be 10
$value | Should Not Be 5

# null/empty チェック
$value | Should BeNullOrEmpty
$value | Should Not BeNullOrEmpty

# 型チェック
$value | Should BeOfType [string]
$value | Should BeOfType [int]

# 真偽値
$value | Should Be $true
$value | Should Be $false

# 例外
{ throw "error" } | Should Throw
{ "no error" } | Should Not Throw

# 正規表現マッチ
$value | Should Match "pattern"
$value | Should Not Match "pattern"

# コレクション
$array | Should Contain "item"
$array | Should Not Contain "item"

# 数値比較（Pester 3.4.0以降）
$value | Should BeGreaterThan 5
$value | Should BeLessThan 10
```

## ベストプラクティス

### 1. Arrange-Act-Assert パターン

```powershell
It "should do something" {
    # Arrange: テストデータの準備
    $config = @{
        Id = "test-1"
        Name = "Test"
    }
    
    # Act: テスト対象の実行
    $result = $service.DoSomething($config)
    
    # Assert: 結果の検証
    $result | Should Not BeNullOrEmpty
    $result.Id | Should Be "test-1"
}
```

### 2. 明確なテスト名

```powershell
# ❌ 不明確
It "test1" { }

# ✅ 明確
It "新しい接続を追加できる" { }
It "設定がnullの場合は例外をスローする" { }
```

### 3. Context でグループ化

```powershell
Describe "ConnectionService" {
    Context "AddConnection" {
        It "正常ケース1" { }
        It "正常ケース2" { }
        It "異常ケース1" { }
    }
    
    Context "GetConnection" {
        It "正常ケース1" { }
        It "異常ケース1" { }
    }
}
```

### 4. BeforeEach で初期化

```powershell
Describe "Tests" {
    BeforeEach {
        # 各テストケースごとに新しいインスタンスを作成
        $script:Service = [MyService]::new()
    }
    
    It "test1" {
        # $script:Service は新しいインスタンス
    }
    
    It "test2" {
        # $script:Service はtest1とは別の新しいインスタンス
    }
}
```

## まとめ

Pester 3.x対応のポイント：

1. ✅ **Should構文**: ハイフンを削除（`Should -Be` → `Should Be`）
2. ✅ **BeforeAll**: Describeの外でモジュールロード
3. ✅ **TestCases**: ForEach-Objectで代替
4. ✅ **明確なテスト名**: 日本語でもOK
5. ✅ **AAA パターン**: Arrange-Act-Assert

これらのガイドラインに従うことで、Windows PowerShell 5.1標準のPester 3.4.0で動作するテストを作成できます。
