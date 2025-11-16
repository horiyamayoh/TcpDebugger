# Tests/Unit/Core/Domain/VariableScope.Tests.ps1

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")
. (Join-Path $repoRoot "Core\Domain\VariableScope.ps1")

Describe 'VariableScope' {
    It 'returns initial values' {
        $scope = New-VariableScope -InitialValues @{ Foo = "Bar" }
        $scope.GetValue("Foo", $null) | Should Be "Bar"
        $scope.Contains("Foo") | Should Be $true
    }

    It 'merges without overwriting by default' {
        $scope = New-VariableScope -InitialValues @{ Foo = "Bar" }
        $scope.Merge(@{ Foo = "Baz"; Bar = 1 }, $false)
        $scope.GetValue("Foo", $null) | Should Be "Bar"
        $scope.GetValue("Bar", $null) | Should Be 1
    }

    It 'creates independent snapshot' {
        $scope = New-VariableScope
        $scope.SetValue("Key", 10)
        $snapshot = $scope.Snapshot()
        $snapshot.Key | Should Be 10
        $scope.SetValue("Key", 20)
        $snapshot.Key | Should Be 10
    }
}
