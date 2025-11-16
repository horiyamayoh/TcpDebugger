# Core/Infrastructure/ServiceContainer.ps1
# Lightweight dependency injection container

class ServiceContainer {
    hidden [hashtable]$_services
    hidden [hashtable]$_singletons

    ServiceContainer() {
        $this._services = @{}
        $this._singletons = @{}
    }

    [void] RegisterSingleton(
        [string]$name,
        [scriptblock]$factory
    ) {
        $this.RegisterService($name, 'Singleton', $factory)
    }

    [void] RegisterTransient(
        [string]$name,
        [scriptblock]$factory
    ) {
        $this.RegisterService($name, 'Transient', $factory)
    }

    [object] Resolve([string]$name) {
        if (-not $this._services.ContainsKey($name)) {
            throw "Service not registered: $name"
        }

        $service = $this._services[$name]

        if ($service.Type -eq 'Singleton') {
            if (-not $this._singletons.ContainsKey($name)) {
                $this._singletons[$name] = & $service.Factory $this
            }
            return $this._singletons[$name]
        }

        return & $service.Factory $this
    }

    hidden [void] RegisterService(
        [string]$name,
        [string]$lifetime,
        [scriptblock]$factory
    ) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Service name cannot be empty."
        }

        if (-not $factory) {
            throw "Factory cannot be null for service '$name'."
        }

        $this._services[$name] = @{
            Type = $lifetime
            Factory = $factory
        }
    }
}

function New-ServiceContainer {
    return [ServiceContainer]::new()
}
