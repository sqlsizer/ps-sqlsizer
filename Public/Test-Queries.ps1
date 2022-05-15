function Test-Queries
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [Query[]]$Queries,

        [Parameter(Mandatory=$false)]
        [bool]$EdgeMode = $false,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $unreachable = Find-SubsetUnreachableTables -Database $Database -Queries $Queries -ConnectionInfo $ConnectionInfo -DatabaseInfo $DatabaseInfo -EdgeMode $EdgeMode

    if ($unreachable.Count -gt 0)
    {
        Write-Host "$($unreachable.Length) are not reachable by queries:" -ForegroundColor Red
        foreach ($item in $unreachable)
        {
            Write-Host $item
        }
        return $false
    }
    else
    {
        return $true
    }
}