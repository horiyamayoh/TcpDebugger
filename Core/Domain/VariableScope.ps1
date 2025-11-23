# Core/Domain/VariableScope.ps1
# Thread-safe variable scope abstraction for connections and scenarios

class VariableScope {
    hidden [System.Collections.Hashtable]$_values
    hidden [object]$_lock

    VariableScope([hashtable]$initialValues) {
        $this._values = [System.Collections.Hashtable]::Synchronized(@{})
        $this._lock = [object]::new()

        if ($initialValues) {
            foreach ($key in $initialValues.Keys) {
                $this._values[$key] = $initialValues[$key]
            }
        }
    }

    [void] SetValue([string]$key, $value) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw "Variable key cannot be empty."
        }
        $this._values[$key] = $value
    }

    [object] GetValue([string]$key, $defaultValue) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            return $defaultValue
        }

        if ($this._values.ContainsKey($key)) {
            return $this._values[$key]
        }

        return $defaultValue
    }

    [bool] Contains([string]$key) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            return $false
        }
        return $this._values.ContainsKey($key)
    }

    [void] Remove([string]$key) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            return
        }
        $this._values.Remove($key)
    }

    [hashtable] Snapshot() {
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            $copy = @{}
            foreach ($key in $this._values.Keys) {
                $copy[$key] = $this._values[$key]
            }
            return $copy
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }

    [void] Merge([hashtable]$values, [bool]$Overwrite = $false) {
        if (-not $values) { return }
        foreach ($key in $values.Keys) {
            if ($Overwrite -or -not $this._values.ContainsKey($key)) {
                $this._values[$key] = $values[$key]
            }
        }
    }

    [void] Clear() {
        $this._values.Clear()
    }

    [int] Count() {
        return $this._values.Count
    }
}

function New-VariableScope {
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$InitialValues = @{}
    )

    return [VariableScope]::new($InitialValues)
}
