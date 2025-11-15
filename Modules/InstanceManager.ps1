# InstanceManager.ps1
# インスタンス管理モジュール - インスタンスの読み込みと論理グループ管理

function Find-InstanceFolders {
    <#
    .SYNOPSIS
    Instancesフォルダをスキャンしてインスタンス設定を読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancesPath
    )
    
    if (-not (Test-Path $InstancesPath)) {
        Write-Warning "Instances folder not found: $InstancesPath"
        return @()
    }
    
    Write-Host "[InstanceManager] Scanning instances in: $InstancesPath" -ForegroundColor Cyan
    
    $instances = @()
    
    # サブフォルダを列挙
    $folders = Get-ChildItem -Path $InstancesPath -Directory
    
    foreach ($folder in $folders) {
        $instanceFile = Join-Path $folder.FullName "instance.psd1"
        
        if (Test-Path $instanceFile) {
            try {
                # PSD1ファイルを読み込み
                $config = Import-PowerShellDataFile -Path $instanceFile
                
                # フォルダ名をベース名として使用
                $config['FolderName'] = $folder.Name
                $config['FolderPath'] = $folder.FullName
                
                # ID未指定の場合はフォルダ名から生成
                if (-not $config.Id) {
                    $config['Id'] = $folder.Name -replace '\s', '-'
                }
                
                # DisplayName未指定の場合はフォルダ名を使用
                if (-not $config.DisplayName) {
                    $config['DisplayName'] = $folder.Name
                }
                
                $instances += [PSCustomObject]$config
                
                Write-Host "  [+] Found instance: $($config.DisplayName)" -ForegroundColor Green
                
            } catch {
                Write-Warning "Failed to load instance from $instanceFile : $_"
            }
        }
    }
    
    Write-Host "[InstanceManager] Loaded $($instances.Count) instances" -ForegroundColor Green
    
    return $instances
}

function Initialize-InstanceConnections {
    <#
    .SYNOPSIS
    インスタンス設定から接続を作成
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Instances
    )
    
    Write-Host "[InstanceManager] Initializing connections from instances..." -ForegroundColor Cyan
    
    foreach ($instance in $Instances) {
        try {
            # 接続設定を構築
            $connConfig = @{
                Id = $instance.Id
                Name = $instance.FolderName
                DisplayName = $instance.DisplayName
                Protocol = $instance.Connection.Protocol
                Mode = $instance.Connection.Mode
                LocalIP = $instance.Connection.LocalIP
                LocalPort = $instance.Connection.LocalPort
                RemoteIP = $instance.Connection.RemoteIP
                RemotePort = $instance.Connection.RemotePort
                Group = $instance.Group
                Tags = $instance.Tags
            }
            
            # 接続を追加
            $conn = Add-Connection -Config $connConfig
            
            # インスタンス固有の設定を保存
            $conn.Variables['InstancePath'] = $instance.FolderPath
            $conn.Variables['DefaultEncoding'] = $instance.DefaultEncoding
            $conn.Variables['AutoScenario'] = $instance.AutoScenario
            
            Write-Host "  [+] Initialized connection: $($conn.DisplayName)" -ForegroundColor Green
            
        } catch {
            Write-Error "Failed to initialize instance $($instance.DisplayName): $_"
        }
    }
    
    Write-Host "[InstanceManager] Connection initialization completed" -ForegroundColor Green
}

function Start-AutoStartConnections {
    <#
    .SYNOPSIS
    AutoStart=trueの接続を自動開始
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Instances
    )
    
    Write-Host "[InstanceManager] Starting auto-start connections..." -ForegroundColor Cyan
    
    foreach ($instance in $Instances) {
        if ($instance.AutoStart -eq $true) {
            try {
                Write-Host "  [+] Auto-starting: $($instance.DisplayName)" -ForegroundColor Cyan
                Start-Connection -ConnectionId $instance.Id
                
                # AutoScenarioがある場合は実行
                if ($instance.AutoScenario) {
                    $scenarioPath = Join-Path $instance.FolderPath "scenarios\$($instance.AutoScenario)"
                    if (Test-Path $scenarioPath) {
                        Start-Sleep -Seconds 1  # 接続確立を待つ
                        Start-Scenario -ConnectionId $instance.Id -ScenarioPath $scenarioPath
                    }
                }
                
            } catch {
                Write-Error "Failed to auto-start $($instance.DisplayName): $_"
            }
        }
    }
    
    Write-Host "[InstanceManager] Auto-start completed" -ForegroundColor Green
}

function Get-InstanceScenarios {
    <#
    .SYNOPSIS
    インスタンスフォルダ内のシナリオファイル一覧を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )
    
    $scenariosPath = Join-Path $InstancePath "scenarios"
    
    if (-not (Test-Path $scenariosPath)) {
        return @()
    }
    
    $scenarios = Get-ChildItem -Path $scenariosPath -Filter "*.csv" | Select-Object -ExpandProperty Name
    
    return $scenarios
}

function Get-InstanceDataBank {
    <#
    .SYNOPSIS
    インスタンスフォルダ内のデータバンクを読み込み
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )
    
    $databankPath = Join-Path $InstancePath "templates\databank.csv"
    
    if (Test-Path $databankPath) {
        return Read-DataBank -FilePath $databankPath
    }
    
    return @()
}

function Get-GroupNames {
    <#
    .SYNOPSIS
    全接続のグループ名一覧を取得
    #>
    
    $groups = @()
    
    foreach ($conn in $Global:Connections.Values) {
        if ($conn.Group -and $conn.Group -notin $groups) {
            $groups += $conn.Group
        }
    }
    
    return $groups | Sort-Object
}

function Get-AllTags {
    <#
    .SYNOPSIS
    全接続のタグ一覧を取得
    #>
    
    $tags = @()
    
    foreach ($conn in $Global:Connections.Values) {
        if ($conn.Tags) {
            foreach ($tag in $conn.Tags) {
                if ($tag -notin $tags) {
                    $tags += $tag
                }
            }
        }
    }
    
    return $tags | Sort-Object
}

# Export-ModuleMember -Function @(
#     'Find-InstanceFolders',
#     'Initialize-InstanceConnections',
#     'Start-AutoStartConnections',
#     'Get-InstanceScenarios',
#     'Get-InstanceDataBank',
#     'Get-GroupNames',
#     'Get-AllTags'
# )
