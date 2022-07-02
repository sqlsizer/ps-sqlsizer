function Test-Queries
{
    [cmdletbinding()]
    [outputtype([System.Boolean])]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [Query[]]$Queries,

        [Parameter(Mandatory=$false)]
        [ColorMap]$ColorMap = $null,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $unreachable = Find-UnreachableTables -Database $Database -Queries $Queries -ConnectionInfo $ConnectionInfo -DatabaseInfo $DatabaseInfo -ColorMap $ColorMap

    if ($unreachable.Count -gt 0)
    {
        Write-Output "$($unreachable.Length) are not reachable by queries:"
        foreach ($item in $unreachable)
        {
            Write-Output $item
        }
        return $false
    }
    else
    {
        return $true
    }
}