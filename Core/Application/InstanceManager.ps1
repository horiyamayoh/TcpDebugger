function Get-InstanceRepository {
    if ($Global:InstanceRepository) {
        return $Global:InstanceRepository
    }
    throw "InstanceRepository is not initialized."
}




function Find-InstanceFolders {
    <#
    .SYNOPSIS
    Instancesフォルダーからインスタンス設定を読み込む
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancesPath
    )

    $repository = Get-InstanceRepository
    Write-Console "[InstanceManager] Scanning instances in: $InstancesPath" -ForegroundColor Cyan
    $instances = $repository.GetInstances($InstancesPath)
    Write-Console "[InstanceManager] Loaded $($instances.Count) instances" -ForegroundColor Green
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
    
    Write-Console "[InstanceManager] Initializing connections from instances..." -ForegroundColor Cyan
    
    $usedIds = @{}
    
    foreach ($instance in $Instances) {
        try {
            # ID重複チェック
            if ($usedIds.ContainsKey($instance.Id)) {
                Write-Warning "  [!] Duplicate instance ID detected: '$($instance.Id)' in folder '$($instance.FolderName)' (already used by '$($usedIds[$instance.Id])'). Skipping..."
                continue
            }
            
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
            $conn.Variables['InstanceName'] = $instance.FolderName
            $conn.Variables['InstancePath'] = $instance.FolderPath
            $conn.Variables['DefaultEncoding'] = $instance.DefaultEncoding
            $conn.Variables['AutoScenario'] = $instance.AutoScenario
            
            $usedIds[$instance.Id] = $instance.FolderName
            
            Write-Console "  [+] Initialized connection: $($conn.DisplayName)" -ForegroundColor Green
            
        } catch {
            Write-Error "Failed to initialize instance $($instance.DisplayName): $_"
        }
    }
    
    Write-Console "[InstanceManager] Connection initialization completed" -ForegroundColor Green
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
    
    Write-Console "[InstanceManager] Starting auto-start connections..." -ForegroundColor Cyan
    
    foreach ($instance in $Instances) {
        if ($instance.AutoStart -eq $true) {
            try {
                Write-Console "  [+] Auto-starting: $($instance.DisplayName)" -ForegroundColor Cyan
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
    
    Write-Console "[InstanceManager] Auto-start completed" -ForegroundColor Green
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

    if (-not (Test-Path -LiteralPath $databankPath)) {
        return @()
    }

    if (-not $script:DataBankIndexCache) {
        $script:DataBankIndexCache = @{}
    }

    $fileInfo = Get-Item -LiteralPath $databankPath
    $lastWrite = $fileInfo.LastWriteTimeUtc

    if ($script:DataBankIndexCache.ContainsKey($databankPath)) {
        $cached = $script:DataBankIndexCache[$databankPath]
        if ($cached.LastWrite -eq $lastWrite) {
            return $cached.Items
        }
    }

    try {
        # UTF-8でCSV読み込み
        $content = Get-Content -Path $databankPath -Encoding UTF8 -Raw
        $rows = $content | ConvertFrom-Csv
    } catch {
        Write-Warning "Failed to read databank: $_"
        return @()
    }

    $items = @()
    foreach ($row in $rows) {
        if (-not $row.DataID) { continue }
        $items += [PSCustomObject]@{
            DataID      = [string]$row.DataID
            Description = $row.Description
        }
    }

    $cacheEntry = [PSCustomObject]@{
        LastWrite = $lastWrite
        Items     = $items
    }

    $script:DataBankIndexCache[$databankPath] = $cacheEntry

    return $items
}

function Get-GroupNames {
    <#
    .SYNOPSIS
    全接続のグループ名一覧を取得
    #>
    
    $groups = @()
    $service = Get-ConnectionService
    
    foreach ($conn in $service.GetAllConnections()) {
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
    $service = Get-ConnectionService
    
    foreach ($conn in $service.GetAllConnections()) {
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

function Get-InstanceOnReceiveReplyProfiles {
    <#
    .SYNOPSIS
    インスタンスの On Receive: Reply プロファイル一覧を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )

    if (-not $InstancePath) {
        return @()
    }

    $profilesPath = Join-Path $InstancePath "scenarios\on_receive_reply"

    if (-not (Test-Path $profilesPath)) {
        return @()
    }

    $items = @()

    foreach ($file in Get-ChildItem -Path $profilesPath -Filter "*.csv" -File) {
        $items += [PSCustomObject]@{
            Name        = $file.BaseName
            DisplayName = $file.BaseName
            FilePath    = $file.FullName
        }
    }

    return $items | Sort-Object DisplayName
}

function Get-InstanceOnReceiveScriptProfiles {
    <#
    .SYNOPSIS
    インスタンスの On Receive: Script プロファイル一覧を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )

    if (-not $InstancePath) {
        return @()
    }

    $profilesPath = Join-Path $InstancePath "scenarios\on_receive_script"

    if (-not (Test-Path $profilesPath)) {
        return @()
    }

    $items = @()

    foreach ($file in Get-ChildItem -Path $profilesPath -Filter "*.csv" -File) {
        $items += [PSCustomObject]@{
            Name        = $file.BaseName
            DisplayName = $file.BaseName
            FilePath    = $file.FullName
        }
    }

    return $items | Sort-Object DisplayName
}

function Get-InstanceOnTimerSendProfiles {
    <#
    .SYNOPSIS
    インスタンスの On Timer: Send プロファイル一覧を取得
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )

    if (-not $InstancePath) {
        return @()
    }

    $profilesPath = Join-Path $InstancePath "scenarios\on_timer_send"

    if (-not (Test-Path $profilesPath)) {
        return @()
    }

    $items = @()

    foreach ($file in Get-ChildItem -Path $profilesPath -Filter "*.csv" -File) {
        $items += [PSCustomObject]@{
            ProfileName = $file.BaseName
            DisplayName = $file.BaseName
            FilePath    = $file.FullName
        }
    }

    return $items | Sort-Object DisplayName
}
















function Get-ManualSendCatalog {
    <#
    .SYNOPSIS
    インスタンスの Manual: Send カタログを取得（UI用）
    
    .DESCRIPTION
    templates/ フォルダ内のCSVファイル（電文テンプレート）を一覧として返す
    databank.csv は除外する
    
    .PARAMETER InstancePath
    インスタンスのルートパス
    
    .OUTPUTS
    TemplatesPath: テンプレートフォルダのパス
    Entries: ファイル名とパスのリスト
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )

    $templatesPath = Join-Path $InstancePath "templates"

    if (-not (Test-Path -LiteralPath $templatesPath)) {
        return [PSCustomObject]@{
            TemplatesPath = $null
            Entries = @()
        }
    }

    # templatesフォルダ内のCSVファイルを取得（databank.csvは除外）
    $entries = @()
    $csvFiles = Get-ChildItem -Path $templatesPath -Filter "*.csv" -File | Where-Object { $_.Name -ne "databank.csv" }
    
    foreach ($file in $csvFiles) {
        $entries += [PSCustomObject]@{
            FileName = $file.BaseName
            FilePath = $file.FullName
            Display  = $file.BaseName
        }
    }

    return [PSCustomObject]@{
        TemplatesPath = $templatesPath
        Entries = $entries | Sort-Object Display
    }
}

function Get-ManualScriptCatalog {
    <#
    .SYNOPSIS
    インスタンスの Manual: Script カタログを取得（UI用）
    
    .DESCRIPTION
    scenarios/manual_scripts/ フォルダ内のps1ファイルを一覧として返す
    
    .PARAMETER InstancePath
    インスタンスのルートパス
    
    .OUTPUTS
    ScriptsPath: スクリプトフォルダのパス
    Entries: ファイル名とパスのリスト
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstancePath
    )

    $scriptsPath = Join-Path $InstancePath "scenarios\manual_scripts"

    if (-not (Test-Path -LiteralPath $scriptsPath)) {
        return [PSCustomObject]@{
            ScriptsPath = $null
            Entries = @()
        }
    }

    # manual_scriptsフォルダ内のps1ファイルを取得
    $entries = @()
    $ps1Files = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" -File
    
    foreach ($file in $ps1Files) {
        $entries += [PSCustomObject]@{
            FileName = $file.BaseName
            FilePath = $file.FullName
            Display  = $file.BaseName
        }
    }

    return [PSCustomObject]@{
        ScriptsPath = $scriptsPath
        Entries = $entries | Sort-Object Display
    }
}
