class InstanceProfile {
    [string]$ProfileName
    [string]$AutoResponseScenario
    [string]$OnReceivedScenario
    [string]$PeriodicScenario
    InstanceProfile([string]$profileName) {
        $this.ProfileName = $profileName
        $this.AutoResponseScenario = ''
        $this.OnReceivedScenario = ''
        $this.PeriodicScenario = ''
    }
    static [InstanceProfile] FromCsvRow([PSCustomObject]$row) {
        $profile = [InstanceProfile]::new($row.ProfileName)
        $profile.AutoResponseScenario = if ($row.AutoResponseScenario) { $row.AutoResponseScenario } else { '' }
        $profile.OnReceivedScenario = if ($row.OnReceivedScenario) { $row.OnReceivedScenario } else { '' }
        $profile.PeriodicScenario = if ($row.PeriodicScenario) { $row.PeriodicScenario } else { '' }
        return $profile
    }
    [PSCustomObject] ToCsvRow() {
        return [PSCustomObject]@{
            ProfileName = $this.ProfileName
            AutoResponseScenario = $this.AutoResponseScenario
            OnReceivedScenario = $this.OnReceivedScenario
            PeriodicScenario = $this.PeriodicScenario
        }
    }
}
class ApplicationProfile {
    [string]$ProfileName
    [hashtable]$InstanceProfileMap
    ApplicationProfile([string]$profileName) {
        $this.ProfileName = $profileName
        $this.InstanceProfileMap = @{}
    }
    [void] SetInstanceProfile([string]$instanceName, [string]$profileName) {
        if (-not [string]::IsNullOrWhiteSpace($instanceName)) {
            $this.InstanceProfileMap[$instanceName] = $profileName
        }
    }
    [string] GetInstanceProfile([string]$instanceName) {
        if ($this.InstanceProfileMap.ContainsKey($instanceName)) {
            return $this.InstanceProfileMap[$instanceName]
        }
        return ''
    }
    [string[]] GetInstanceNames() {
        return $this.InstanceProfileMap.Keys
    }
    static [ApplicationProfile] FromCsvRow([PSCustomObject]$row, [string[]]$instanceNames) {
        $profile = [ApplicationProfile]::new($row.ProfileName)
        foreach ($instanceName in $instanceNames) {
            if ($row.PSObject.Properties.Name -contains $instanceName) {
                $instProfileName = $row.$instanceName
                if (-not [string]::IsNullOrWhiteSpace($instProfileName)) {
                    $profile.SetInstanceProfile($instanceName, $instProfileName)
                }
            }
        }
        return $profile
    }
    [PSCustomObject] ToCsvRow([string[]]$instanceNames) {
        $obj = [PSCustomObject]@{ ProfileName = $this.ProfileName }
        foreach ($instanceName in $instanceNames) {
            $instProfileName = $this.GetInstanceProfile($instanceName)
            $obj | Add-Member -NotePropertyName $instanceName -NotePropertyValue $instProfileName
        }
        return $obj
    }
}
