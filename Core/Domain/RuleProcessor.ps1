class RuleProcessor {
    hidden [Logger]$_logger
    hidden [RuleRepository]$_ruleRepository

    RuleProcessor(
        [Logger]$logger,
        [RuleRepository]$ruleRepository
    ) {
        if (-not $logger) {
            throw "Logger instance is required for RuleProcessor."
        }
        if (-not $ruleRepository) {
            throw "RuleRepository instance is required for RuleProcessor."
        }

        $this._logger = $logger
        $this._ruleRepository = $ruleRepository
    }

    [void] ProcessRules(
        [ManagedConnection]$connection,
        [byte[]]$data
    ) {
        if (-not $connection -or -not $data -or $data.Length -eq 0) {
            return
        }

        try {
            $autoProfilePath = $this.GetProfilePath($connection, 'AutoResponseProfilePath')
            $onReceivedProfilePath = $this.GetProfilePath($connection, 'OnReceivedProfilePath')

            if (-not $autoProfilePath -and -not $onReceivedProfilePath) {
                return
            }

            $autoRules = @()
            if ($autoProfilePath) {
                $autoRules = $this._ruleRepository.GetRules($autoProfilePath)
            }

            if ($this.HasUnifiedRules($autoRules)) {
                $this.ProcessUnifiedRules($connection, $data, $autoRules)
                return
            }

            # OnReceivedルールをBefore/Afterに分ける
            $onReceivedRulesBefore = @()
            $onReceivedRulesAfter = @()
            
            if ($onReceivedProfilePath) {
                $onReceivedRules = $this._ruleRepository.GetRules($onReceivedProfilePath)
                if ($onReceivedRules -and $onReceivedRules.Count -gt 0) {
                    foreach ($rule in $onReceivedRules) {
                        if ($rule.__ExecutionTiming -eq 'Before') {
                            $onReceivedRulesBefore += $rule
                        } else {
                            $onReceivedRulesAfter += $rule
                        }
                    }
                }
            }

            # 1. Before OnReceived を実行
            if ($onReceivedRulesBefore.Count -gt 0) {
                $this.ProcessOnReceived($connection, $data, $onReceivedRulesBefore)
            }

            # 2. AutoResponse を実行
            if ($autoRules -and $autoRules.Count -gt 0) {
                $this.ProcessAutoResponse($connection, $data, $autoRules)
            }

            # 3. After OnReceived を実行
            if ($onReceivedRulesAfter.Count -gt 0) {
                $this.ProcessOnReceived($connection, $data, $onReceivedRulesAfter)
            }
        }
        catch {
            $this._logger.LogError("Rule processing failed", $_.Exception, @{
                ConnectionId = $connection.Id
            })
        }
    }

    hidden [string] GetProfilePath(
        [ManagedConnection]$connection,
        [string]$variableName
    ) {
        if (-not $connection -or -not $connection.Variables) {
            return $null
        }

        if ($connection.Variables.ContainsKey($variableName)) {
            $value = $connection.Variables[$variableName]
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }

        return $null
    }

    hidden [bool] HasUnifiedRules([object[]]$rules) {
        if (-not $rules -or $rules.Count -eq 0) {
            return $false
        }

        $firstRule = $rules[0]
        if (-not $firstRule) {
            return $false
        }

        if ($firstRule.PSObject.Properties.Name -contains '__RuleType') {
            return $firstRule.__RuleType -eq 'Unified'
        }

        return $false
    }

    hidden [void] ProcessUnifiedRules(
        [ManagedConnection]$connection,
        [byte[]]$data,
        [object[]]$rules
    ) {
        try {
            Invoke-AutoResponse -ConnectionId $connection.Id -ReceivedData $data -Rules $rules
        }
        catch {
            $this._logger.LogError("Unified rule execution failed", $_.Exception, @{
                ConnectionId = $connection.Id
                Profile = 'Unified'
            })
        }
    }

    hidden [void] ProcessAutoResponse(
        [ManagedConnection]$connection,
        [byte[]]$data,
        [object[]]$rules
    ) {
        try {
            Invoke-AutoResponse -ConnectionId $connection.Id -ReceivedData $data -Rules $rules
        }
        catch {
            $this._logger.LogError("AutoResponse execution failed", $_.Exception, @{
                ConnectionId = $connection.Id
                Profile = 'AutoResponse'
            })
        }
    }

    hidden [void] ProcessOnReceived(
        [ManagedConnection]$connection,
        [byte[]]$data,
        [object[]]$rules
    ) {
        $matchedCount = 0

        foreach ($rule in $rules) {
            try {
                if (-not (Test-OnReceivedMatch -ReceivedData $data -Rule $rule)) {
                    continue
                }
            }
            catch {
                $this._logger.LogWarning("OnReceived rule match failed", @{
                    ConnectionId = $connection.Id
                    RuleName = $rule.RuleName
                    Error = $_.Exception.Message
                })
                continue
            }

            $matchedCount++

            if ($rule.Delay -and [int]$rule.Delay -gt 0) {
                Start-Sleep -Milliseconds ([int]$rule.Delay)
            }

            try {
                Invoke-OnReceivedScript -ConnectionId $connection.Id -ReceivedData $data -Rule $rule -Connection $connection
            }
            catch {
                $this._logger.LogWarning("OnReceived script execution failed", @{
                    ConnectionId = $connection.Id
                    RuleName = $rule.RuleName
                    Error = $_.Exception.Message
                })
            }
        }

        if ($matchedCount -gt 0) {
            $this._logger.LogInfo("Processed OnReceived rules", @{
                ConnectionId = $connection.Id
                MatchedRules = $matchedCount
            })
        }
    }
}
