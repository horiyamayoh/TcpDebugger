# Core/Infrastructure/Repositories/InstanceRepository.ps1

class InstanceRepository {
    hidden [Logger]$_logger

    InstanceRepository([Logger]$logger) {
        if (-not $logger) {
            throw "Logger instance is required for InstanceRepository."
        }
        $this._logger = $logger
    }

    [PSCustomObject[]] GetInstances([string]$instancesPath) {
        if ([string]::IsNullOrWhiteSpace($instancesPath)) {
            return @()
        }

        if (-not (Test-Path -LiteralPath $instancesPath)) {
            $this._logger.LogWarning("Instances folder not found", @{
                Path = $instancesPath
            })
            return @()
        }

        $result = @()
        $folders = Get-ChildItem -Path $instancesPath -Directory

        foreach ($folder in $folders) {
            $instanceFile = Join-Path $folder.FullName "instance.psd1"

            if (-not (Test-Path -LiteralPath $instanceFile)) {
                continue
            }

            try {
                $config = Import-PowerShellDataFile -Path $instanceFile

                $config['FolderName'] = $folder.Name
                $config['FolderPath'] = $folder.FullName

                if (-not $config.Id) {
                    $config['Id'] = $folder.Name -replace '\s', '-'
                }

                if (-not $config.DisplayName) {
                    $config['DisplayName'] = $folder.Name
                }

                if (-not $config.Connection) {
                    $config['Connection'] = @{
                        Protocol  = 'TCP'
                        Mode      = 'Client'
                        LocalIP   = '127.0.0.1'
                        LocalPort = 0
                        RemoteIP  = ''
                        RemotePort = 0
                    }
                }

                $result += [PSCustomObject]$config
                $this._logger.LogInfo("Instance loaded", @{
                    Instance = $config.DisplayName
                    Folder   = $folder.FullName
                })
            }
            catch {
                $this._logger.LogWarning("Failed to load instance", @{
                    InstanceFile = $instanceFile
                    Error        = $_.Exception.Message
                })
            }
        }

        return $result
    }
}
