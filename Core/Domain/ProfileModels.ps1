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
        
        # CSV列をスキャンし、実際に存在するインスタンスにのみマッピング
        # これにより、CSV列とインスタンスが完全一致しなくても動作する
        foreach ($property in $row.PSObject.Properties) {
            $columnName = $property.Name
            
            # ProfileName列はスキップ（これはプロファイル名自体）
            if ($columnName -eq 'ProfileName') {
                continue
            }
            
            # この列名が実際のインスタンス名と一致するかチェック
            if ($instanceNames -contains $columnName) {
                $instProfileName = $property.Value
                if (-not [string]::IsNullOrWhiteSpace($instProfileName)) {
                    $profile.SetInstanceProfile($columnName, $instProfileName)
                }
            }
            # 一致しない列は単純に無視（エラーにしない）
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
