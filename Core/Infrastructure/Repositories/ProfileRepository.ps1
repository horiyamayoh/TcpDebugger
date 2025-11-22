. "$PSScriptRoot\..\..\Domain\ProfileModels.ps1"
class ProfileRepository {
    [object]$Logger
    ProfileRepository([object]$logger) {
        $this.Logger = $logger
    }
    [System.Collections.Generic.List[object]] LoadInstanceProfiles([string]$csvPath) {
        $profiles = [System.Collections.Generic.List[object]]::new()
        if (-not (Test-Path $csvPath)) {
            $this.Logger.LogWarning("Profile file not found: $csvPath", @{})
            return $profiles
        }
        try {
            $rows = Import-Csv -Path $csvPath -Encoding UTF8
            foreach ($row in $rows) {
                if ([string]::IsNullOrWhiteSpace($row.ProfileName)) { continue }
                $profile = [InstanceProfile]::FromCsvRow($row)
                $profiles.Add($profile)
            }
        } catch {
            $this.Logger.LogError("Failed to load profiles: $_", $_.Exception, @{})
        }
        return $profiles
    }
    [void] SaveInstanceProfiles([System.Collections.Generic.List[object]]$profiles, [string]$csvPath) {
        try {
            $rows = foreach ($profile in $profiles) { $profile.ToCsvRow() }
            $rows | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
        } catch {
            $this.Logger.LogError("Failed to save profiles: $_", $_.Exception, @{})
        }
    }
    [System.Collections.Generic.List[object]] LoadApplicationProfiles([string]$csvPath, [string[]]$instanceNames) {
        $profiles = [System.Collections.Generic.List[object]]::new()
        if (-not (Test-Path $csvPath)) {
            $this.Logger.LogWarning("App profile file not found: $csvPath", @{})
            return $profiles
        }
        try {
            $rows = Import-Csv -Path $csvPath -Encoding UTF8
            foreach ($row in $rows) {
                if ([string]::IsNullOrWhiteSpace($row.ProfileName)) { continue }
                $profile = [ApplicationProfile]::FromCsvRow($row, $instanceNames)
                $profiles.Add($profile)
            }
        } catch {
            $this.Logger.LogError("Failed to load app profiles: $_", $_.Exception, @{})
        }
        return $profiles
    }
    [void] SaveApplicationProfiles([System.Collections.Generic.List[object]]$profiles, [string]$csvPath, [string[]]$instanceNames) {
        try {
            $rows = foreach ($profile in $profiles) { $profile.ToCsvRow($instanceNames) }
            $rows | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
        } catch {
            $this.Logger.LogError("Failed to save app profiles: $_", $_.Exception, @{})
        }
    }
}
