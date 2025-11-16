# Core/Common/ThreadSafeCollections.ps1
# Helper functions to create synchronized collections and critical sections

function New-ThreadSafeHashtable {
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Seed = @{}
    )

    return [System.Collections.Hashtable]::Synchronized(@{ } + $Seed)
}

function New-ThreadSafeList {
    param(
        [Parameter(Mandatory = $false)]
        [System.Collections.IEnumerable]$Seed
    )

    $list = New-Object System.Collections.ArrayList
    if ($Seed) {
        foreach ($item in $Seed) {
            [void]$list.Add($item)
        }
    }
    return [System.Collections.ArrayList]::Synchronized($list)
}

function New-ThreadSafeQueue {
    param()

    $queue = New-Object System.Collections.Queue
    return [System.Collections.Queue]::Synchronized($queue)
}

function Use-Lock {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Lock,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Script
    )

    [System.Threading.Monitor]::Enter($Lock)
    try {
        return & $Script
    }
    finally {
        [System.Threading.Monitor]::Exit($Lock)
    }
}
