# Tests/Unit/Core/Domain/ConnectionService.Tests.ps1
# ConnectionServiceの単体テスト

# テスト対象モジュールをロード
$rootPath = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
. "$rootPath\Core\Common\Logger.ps1"
. "$rootPath\Core\Common\Exceptions.ps1"
. "$rootPath\Core\Domain\VariableScope.ps1"
. "$rootPath\Core\Domain\ConnectionModels.ps1"
. "$rootPath\Core\Domain\ConnectionService.ps1"

Describe "ConnectionService" {
    BeforeEach {
        # テスト用のロガーを作成
        $script:TestLogger = [Logger]::new("TestDrive:\test.log", "TestLogger", 10, 5, $false)
        
        # テスト用の接続ストアを作成
        $script:TestStore = [System.Collections.Hashtable]::Synchronized(@{})
        
        # ConnectionServiceのインスタンスを作成
        $script:Service = [ConnectionService]::new($script:TestLogger, $script:TestStore)
    }
    
    Context "AddConnection" {
        It "新しい接続を追加できる" {
            # Arrange
            $config = @{
                Id = "test-conn-1"
                Name = "TestConnection"
                DisplayName = "Test Connection 1"
                Protocol = "TCP"
                Mode = "Client"
                RemoteIP = "127.0.0.1"
                RemotePort = 8080
            }
            
            # Act
            $connection = $script:Service.AddConnection($config)
            
            # Assert
            $connection | Should -Not -BeNullOrEmpty
            $connection.Id | Should -Be "test-conn-1"
            $connection.DisplayName | Should -Be "Test Connection 1"
            $connection.Protocol | Should -Be "TCP"
            $connection.Mode | Should -Be "Client"
        }
        
        It "同じIDの接続を重複追加すると既存の接続を返す" {
            # Arrange
            $config = @{
                Id = "test-conn-1"
                Name = "TestConnection"
                Protocol = "TCP"
                Mode = "Client"
            }
            
            # Act
            $conn1 = $script:Service.AddConnection($config)
            $conn2 = $script:Service.AddConnection($config)
            
            # Assert
            $conn1.Id | Should -Be $conn2.Id
            [object]::ReferenceEquals($conn1, $conn2) | Should -Be $true
        }
        
        It "設定がnullの場合は例外をスローする" {
            # Act & Assert
            { $script:Service.AddConnection($null) } | Should -Throw
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
            $connection | Should -Not -BeNullOrEmpty
            $connection.Id | Should -Be "test-conn-1"
        }
        
        It "存在しない接続IDの場合はnullを返す" {
            # Act
            $connection = $script:Service.GetConnection("non-existent")
            
            # Assert
            $connection | Should -BeNullOrEmpty
        }
        
        It "空の接続IDの場合はnullを返す" {
            # Act
            $connection = $script:Service.GetConnection("")
            
            # Assert
            $connection | Should -BeNullOrEmpty
        }
    }
    
    Context "GetAllConnections" {
        It "すべての接続を取得できる" {
            # Arrange
            $config1 = @{ Id = "conn-1"; Name = "Conn1"; Protocol = "TCP" }
            $config2 = @{ Id = "conn-2"; Name = "Conn2"; Protocol = "UDP" }
            $config3 = @{ Id = "conn-3"; Name = "Conn3"; Protocol = "TCP" }
            
            $script:Service.AddConnection($config1)
            $script:Service.AddConnection($config2)
            $script:Service.AddConnection($config3)
            
            # Act
            $connections = $script:Service.GetAllConnections()
            
            # Assert
            $connections.Count | Should -Be 3
        }
        
        It "接続が存在しない場合は空の配列を返す" {
            # Act
            $connections = $script:Service.GetAllConnections()
            
            # Assert
            $connections.Count | Should -Be 0
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
            $connection | Should -BeNullOrEmpty
        }
        
        It "存在しない接続IDでも例外をスローしない" {
            # Act & Assert
            { $script:Service.RemoveConnection("non-existent") } | Should -Not -Throw
        }
    }
    
    Context "GetConnectionsByGroup" {
        It "指定グループの接続のみ取得できる" {
            # Arrange
            $config1 = @{ Id = "conn-1"; Name = "Conn1"; Protocol = "TCP"; Group = "GroupA" }
            $config2 = @{ Id = "conn-2"; Name = "Conn2"; Protocol = "TCP"; Group = "GroupB" }
            $config3 = @{ Id = "conn-3"; Name = "Conn3"; Protocol = "TCP"; Group = "GroupA" }
            
            $script:Service.AddConnection($config1)
            $script:Service.AddConnection($config2)
            $script:Service.AddConnection($config3)
            
            # Act
            $connections = $script:Service.GetConnectionsByGroup("GroupA")
            
            # Assert
            $connections.Count | Should -Be 2
            $connections[0].Group | Should -Be "GroupA"
            $connections[1].Group | Should -Be "GroupA"
        }
        
        It "存在しないグループの場合は空の配列を返す" {
            # Act
            $connections = $script:Service.GetConnectionsByGroup("NonExistent")
            
            # Assert
            $connections.Count | Should -Be 0
        }
    }
    
    Context "GetConnectionsByTag" {
        It "指定タグを持つ接続のみ取得できる" {
            # Arrange
            $config1 = @{ Id = "conn-1"; Name = "Conn1"; Protocol = "TCP"; Tags = @("tag1", "tag2") }
            $config2 = @{ Id = "conn-2"; Name = "Conn2"; Protocol = "TCP"; Tags = @("tag2", "tag3") }
            $config3 = @{ Id = "conn-3"; Name = "Conn3"; Protocol = "TCP"; Tags = @("tag3") }
            
            $script:Service.AddConnection($config1)
            $script:Service.AddConnection($config2)
            $script:Service.AddConnection($config3)
            
            # Act
            $connections = $script:Service.GetConnectionsByTag("tag2")
            
            # Assert
            $connections.Count | Should -Be 2
        }
        
        It "存在しないタグの場合は空の配列を返す" {
            # Act
            $connections = $script:Service.GetConnectionsByTag("NonExistentTag")
            
            # Assert
            $connections.Count | Should -Be 0
        }
    }
    
    Context "ClearConnections" {
        It "すべての接続をクリアできる" {
            # Arrange
            $config1 = @{ Id = "conn-1"; Name = "Conn1"; Protocol = "TCP" }
            $config2 = @{ Id = "conn-2"; Name = "Conn2"; Protocol = "UDP" }
            
            $script:Service.AddConnection($config1)
            $script:Service.AddConnection($config2)
            
            # Act
            $script:Service.ClearConnections()
            
            # Assert
            $connections = $script:Service.GetAllConnections()
            $connections.Count | Should -Be 0
        }
    }
    
    Context "スレッドセーフティ" {
        It "複数スレッドから同時にアクセスしても問題ない" {
            # Arrange
            $jobs = @()
            
            # Act - 複数のバックグラウンドジョブで同時に接続を追加
            1..10 | ForEach-Object {
                $jobScript = {
                    param($i, $logger, $store)
                    
                    # モジュールを再読み込み（ジョブスコープで必要）
                    $rootPath = Split-Path -Parent $using:PSScriptRoot | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
                    . "$rootPath\Core\Common\Logger.ps1"
                    . "$rootPath\Core\Common\Exceptions.ps1"
                    . "$rootPath\Core\Domain\VariableScope.ps1"
                    . "$rootPath\Core\Domain\ConnectionModels.ps1"
                    . "$rootPath\Core\Domain\ConnectionService.ps1"
                    
                    $service = [ConnectionService]::new($logger, $store)
                    
                    $config = @{
                        Id = "conn-$i"
                        Name = "Connection$i"
                        Protocol = "TCP"
                    }
                    
                    $service.AddConnection($config)
                }
                
                $jobs += Start-Job -ScriptBlock $jobScript -ArgumentList $_, $script:TestLogger, $script:TestStore
            }
            
            # すべてのジョブが完了するまで待機
            $jobs | Wait-Job | Out-Null
            $jobs | Remove-Job
            
            # Assert
            $connections = $script:Service.GetAllConnections()
            $connections.Count | Should -Be 10
        }
    }
}
