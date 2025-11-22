. "$PSScriptRoot\ProfileModels.ps1"
class ProfileService {
    [object]$ProfileRepository
    [object]$Logger
    [hashtable]$InstanceProfiles
    [System.Collections.Generic.List[object]]$ApplicationProfiles
    ProfileService([object]$profileRepository, [object]$logger) {
        $this.ProfileRepository = $profileRepository
        $this.Logger = $logger
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
            if (-not [string]::IsNullOrWhiteSpace($profile.AutoResponseScenario)) {
                $scenarioPath = $this.ResolveScenarioPath($instancePath, $profile.AutoResponseScenario)
                if ($scenarioPath -and (Test-Path $scenarioPath)) {
                    # 拡張子なしの名前を取得（完全パスから）
                    $profileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($scenarioPath)
                    Set-ConnectionAutoResponseProfile -ConnectionId $connectionId -ProfileName $profileNameWithoutExt -ProfilePath $scenarioPath 
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($profile.OnReceivedScenario)) {
                $scenarioPath = $this.ResolveScenarioPath($instancePath, $profile.OnReceivedScenario)
                if ($scenarioPath -and (Test-Path $scenarioPath)) {
                    # 拡張子なしの名前を取得（完全パスから）
                    $profileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($scenarioPath)
                    Set-ConnectionOnReceivedProfile -ConnectionId $connectionId -ProfileName $profileNameWithoutExt -ProfilePath $scenarioPath 
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($profile.PeriodicScenario)) {
                $scenarioPath = $this.ResolveScenarioPath($instancePath, $profile.PeriodicScenario)
                if ($scenarioPath -and (Test-Path $scenarioPath)) {
                    # PeriodicSendは内部で自動的に拡張子なし名前を取得するのでそのまま渡す
                    Set-ConnectionPeriodicSendProfile -ConnectionId $connectionId -ProfilePath $scenarioPath -InstancePath $instancePath 
                }
            }
            $connection = Get-UiConnection -ConnectionId $connectionId
            if ($connection) { 
                $connection.Variables['InstanceProfile'] = $profileName 
            }
        } catch { 
            Write-Warning "[ProfileService] Error applying profile: $_"
        }
    }
    [void] ApplyApplicationProfile([string]$appProfileName) {
        try {
            $appProfile = $this.ApplicationProfiles | Where-Object { $_.ProfileName -eq $appProfileName } | Select-Object -First 1
            if (-not $appProfile) { return }
            $connections = Get-AllUiConnections
            foreach ($connection in $connections) {
                $instanceName = $connection.Variables['InstanceName']
                $instancePath = $connection.Variables['InstancePath']
                if ([string]::IsNullOrWhiteSpace($instanceName) -or [string]::IsNullOrWhiteSpace($instancePath)) { continue }
                $instanceProfileName = $appProfile.GetInstanceProfile($instanceName)
                if (-not [string]::IsNullOrWhiteSpace($instanceProfileName)) {
                    $this.ApplyInstanceProfile($connection.Id, $instanceName, $instanceProfileName, $instancePath)
                }
            }
        } catch { }
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
            (Join-Path (Join-Path $instancePath "scenarios") "auto"),
            (Join-Path (Join-Path $instancePath "scenarios") "onreceived"),
            (Join-Path (Join-Path $instancePath "scenarios") "periodic"),
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
