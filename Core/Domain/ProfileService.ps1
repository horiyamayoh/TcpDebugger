. "$PSScriptRoot\ProfileModels.ps1"
class ProfileService {
    [object]$ProfileRepository
    [object]$Logger
    [object]$ConnectionService
    [hashtable]$InstanceProfiles
    [System.Collections.Generic.List[object]]$ApplicationProfiles
    ProfileService([object]$profileRepository, [object]$logger) {
        $this.ProfileRepository = $profileRepository
        $this.Logger = $logger
        $this.ConnectionService = $null
        $this.InstanceProfiles = @{}
        $this.ApplicationProfiles = [System.Collections.Generic.List[object]]::new()
    }
    [void] LoadInstanceProfiles([string]$instanceName, [string]$instancePath) {
        try {
            $profilesPath = Join-Path $instancePath "profiles.csv"
            if (-not (Test-Path $profilesPath)) { return }
            $profiles = $this.ProfileRepository.LoadInstanceProfiles($profilesPath)
            $this.InstanceProfiles[$instanceName] = $profiles
        } catch { }
    }
    [void] LoadApplicationProfiles([string]$csvPath, [string[]]$instanceNames) {
        try {
            if (-not (Test-Path $csvPath)) { return }
            $this.ApplicationProfiles = $this.ProfileRepository.LoadApplicationProfiles($csvPath, $instanceNames)
        } catch { }
    }
    [void] ApplyInstanceProfile([string]$connectionId, [string]$instanceName, [string]$profileName, [string]$instancePath) {
        try {
            if (-not $this.InstanceProfiles.ContainsKey($instanceName)) { $this.LoadInstanceProfiles($instanceName, $instancePath) }
            $profiles = $this.InstanceProfiles[$instanceName]
            $profile = $profiles | Where-Object { $_.ProfileName -eq $profileName } | Select-Object -First 1
            if (-not $profile) { 
                return 
            }
            
            if (-not [string]::IsNullOrWhiteSpace($profile.OnReceiveReply)) {
                $scenarioPath = $this.ResolveScenarioPath($instancePath, $profile.OnReceiveReply)
                if ($scenarioPath -and (Test-Path $scenarioPath)) {
                    # 拡張子なしの名前を取得（完全パスから）
                    $profileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($scenarioPath)
                    Set-ConnectionOnReceiveReplyProfile -ConnectionId $connectionId -ProfileName $profileNameWithoutExt -ProfilePath $scenarioPath 
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($profile.OnReceiveScript)) {
                $scenarioPath = $this.ResolveScenarioPath($instancePath, $profile.OnReceiveScript)
                if ($scenarioPath -and (Test-Path $scenarioPath)) {
                    # 拡張子なしの名前を取得（完全パスから）
                    $profileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($scenarioPath)
                    Set-ConnectionOnReceiveScriptProfile -ConnectionId $connectionId -ProfileName $profileNameWithoutExt -ProfilePath $scenarioPath 
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($profile.OnTimerSend)) {
                $scenarioPath = $this.ResolveScenarioPath($instancePath, $profile.OnTimerSend)
                if ($scenarioPath -and (Test-Path $scenarioPath)) {
                    # OnTimerSendは内部で自動的に拡張子なし名前を取得するのでそのまま渡す
                    Set-ConnectionOnTimerSendProfile -ConnectionId $connectionId -ProfilePath $scenarioPath -InstancePath $instancePath 
                }
            }
            
            # ConnectionServiceを取得
            if (-not $this.ConnectionService) {
                $this.ConnectionService = $Global:ConnectionService
            }
            
            if ($this.ConnectionService) {
                $connection = $this.ConnectionService.GetConnection($connectionId)
                if ($connection) { 
                    $connection.Variables['InstanceProfile'] = $profileName 
                }
            }
        } catch { 
            $this.Logger.Warning("Error applying profile: $_", @{ ConnectionId = $connectionId; ProfileName = $profileName; Exception = $_.Exception.Message })
        }
    }
    [void] ApplyApplicationProfile([string]$appProfileName) {
        try {
            $appProfile = $this.ApplicationProfiles | Where-Object { $_.ProfileName -eq $appProfileName } | Select-Object -First 1
            if (-not $appProfile) { 
                $this.Logger.Warning("Application profile not found: $appProfileName", @{ ProfileName = $appProfileName })
                return 
            }
            
            # ConnectionServiceを取得
            if (-not $this.ConnectionService) {
                $this.ConnectionService = $Global:ConnectionService
            }
            
            if (-not $this.ConnectionService) {
                $this.Logger.Error("ConnectionService is not available")
                return
            }
            
            $connections = $this.ConnectionService.GetAllConnections()
            $appliedCount = 0
            $skippedCount = 0
            $appliedDetails = [System.Collections.Generic.List[string]]::new()
            
            foreach ($connection in $connections) {
                $instanceName = $connection.Variables['InstanceName']
                $instancePath = $connection.Variables['InstancePath']
                
                if ([string]::IsNullOrWhiteSpace($instanceName) -or [string]::IsNullOrWhiteSpace($instancePath)) { 
                    continue 
                }
                
                $instanceProfileName = $appProfile.GetInstanceProfile($instanceName)
                
                if (-not [string]::IsNullOrWhiteSpace($instanceProfileName)) {
                    $this.ApplyInstanceProfile($connection.Id, $instanceName, $instanceProfileName, $instancePath)
                    $appliedCount++
                    $appliedDetails.Add("$instanceName -> $instanceProfileName")
                } else {
                    # CSV列にこのインスタンスの設定がない、または空白
                    $skippedCount++
                    $this.Logger.Debug("No profile mapping for instance: $instanceName", @{ 
                        AppProfile = $appProfileName
                        Instance = $instanceName 
                    })
                }
            }
            
            # 詳細ログ
            if ($appliedCount -gt 0) {
                $detailsText = $appliedDetails -join ', '
                $this.Logger.Info("Applied application profile '$appProfileName' [$detailsText]", @{ 
                    ProfileName = $appProfileName
                    AppliedCount = $appliedCount
                    SkippedCount = $skippedCount
                })
            } else {
                $this.Logger.Warning("Application profile '$appProfileName' applied to 0 connections (skipped: $skippedCount)", @{ 
                    ProfileName = $appProfileName
                    SkippedCount = $skippedCount
                })
            }
        } catch { 
            $this.Logger.Error("Failed to apply application profile: $_", $_.Exception, @{ ProfileName = $appProfileName })
        }
    }
    [string[]] GetAvailableInstanceProfiles([string]$instanceName) {
        if (-not $this.InstanceProfiles.ContainsKey($instanceName)) { return @() }
        return $this.InstanceProfiles[$instanceName] | ForEach-Object { $_.ProfileName }
    }
    [string[]] GetAvailableApplicationProfiles() {
        return $this.ApplicationProfiles | ForEach-Object { $_.ProfileName }
    }
    [string] ResolveScenarioPath([string]$instancePath, [string]$scenarioName) {
        if ([string]::IsNullOrWhiteSpace($scenarioName)) { return $null }
        $paths = @(
            (Join-Path (Join-Path $instancePath "scenarios") "on_receive_reply"),
            (Join-Path (Join-Path $instancePath "scenarios") "on_receive_script"),
            (Join-Path (Join-Path $instancePath "scenarios") "on_timer_send"),
            (Join-Path $instancePath "scenarios"),
            (Join-Path $instancePath "templates")
        )
        foreach ($dir in $paths) {
            $fullPath = Join-Path $dir $scenarioName
            if (Test-Path $fullPath) { return $fullPath }
        }
        return $null
    }
}
