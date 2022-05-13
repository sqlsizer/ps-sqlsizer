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
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $unreachableTables = Find-SubsetUnreachableTables -Database $Database -Queries $Queries -ConnectionInfo $ConnectionInfo -DatabaseInfo $DatabaseInfo

    if ($unreachableTables.Count -gt 0)
    {
        Write-Host "$($unreachableTables.Length) tables are not subset-reachable: " -ForegroundColor Red
        foreach ($table in $unreachableTables)
        {
            Write-Host ($table.SchemaName + "." + $table.TableName)
        }
        return $false
    }
    else
    {
        return $true
    }
}