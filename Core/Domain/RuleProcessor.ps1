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
            $autoProfilePath = $this.GetProfilePath($connection, 'OnReceiveReplyProfilePath')
            $onReceiveScriptProfilePath = $this.GetProfilePath($connection, 'OnReceiveScriptProfilePath')

            if (-not $autoProfilePath -and -not $onReceiveScriptProfilePath) {
                return
            }

            $autoRules = @()
            if ($autoProfilePath) {
                $autoRules = $this._ruleRepository.GetRules($autoProfilePath)
            }

            # OnReceiveScriptルールをBefore/Afterに分ける
            $onReceiveScriptRulesBefore = @()
            $onReceiveScriptRulesAfter = @()
            
            if ($onReceiveScriptProfilePath) {
                $onReceiveScriptRules = $this._ruleRepository.GetRules($onReceiveScriptProfilePath)
                if ($onReceiveScriptRules -and $onReceiveScriptRules.Count -gt 0) {
                    foreach ($rule in $onReceiveScriptRules) {
                        if ($rule.__ExecutionTiming -eq 'Before') {
                            $onReceiveScriptRulesBefore += $rule
                        } else {
                            $onReceiveScriptRulesAfter += $rule
                        }
                    }
                }
            }

            # 1. Before OnReceiveScript を実行
            if ($onReceiveScriptRulesBefore.Count -gt 0) {
                $this.ProcessOnReceiveScript($connection, $data, $onReceiveScriptRulesBefore)
            }

            # 2. OnReceiveReply を実行
            if ($autoRules -and $autoRules.Count -gt 0) {
                $this.ProcessOnReceiveReply($connection, $data, $autoRules)
            }

            # 3. After OnReceiveScript を実行
            if ($onReceiveScriptRulesAfter.Count -gt 0) {
                $this.ProcessOnReceiveScript($connection, $data, $onReceiveScriptRulesAfter)
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

    hidden [void] ProcessOnReceiveReply(
        [ManagedConnection]$connection,
        [byte[]]$data,
        [object[]]$rules
    ) {
        try {
            Invoke-OnReceiveReply -ConnectionId $connection.Id -ReceivedData $data -Rules $rules
        }
        catch {
            $this._logger.LogError("OnReceiveReply execution failed", $_.Exception, @{
                ConnectionId = $connection.Id
                Profile = 'OnReceiveReply'
            })
        }
    }

    hidden [void] ProcessOnReceiveScript(
        [ManagedConnection]$connection,
        [byte[]]$data,
        [object[]]$rules
    ) {
        $matchedCount = 0

        foreach ($rule in $rules) {
            try {
                if (-not (Test-OnReceiveScriptMatch -ReceivedData $data -Rule $rule)) {
                    continue
                }
            }
            catch {
                $this._logger.LogWarning("OnReceiveScript rule match failed", @{
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
                Invoke-OnReceiveScript -ConnectionId $connection.Id -ReceivedData $data -Rule $rule -Connection $connection
            }
            catch {
                $this._logger.LogWarning("OnReceiveScript script execution failed", @{
                    ConnectionId = $connection.Id
                    RuleName = $rule.RuleName
                    Error = $_.Exception.Message
                })
            }
        }

        if ($matchedCount -gt 0) {
            $this._logger.LogInfo("Processed OnReceiveScript rules", @{
                ConnectionId = $connection.Id
                MatchedRules = $matchedCount
            })
        }
    }
}
