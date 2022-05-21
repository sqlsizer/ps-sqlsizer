function Get-SubsetTables
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$false)]
        [boolean]$Negation = $false,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $tables = Get-SubsetTableStatistics -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    if ($Negation -eq $false)
    {
        return $tables | Where-Object {$_.RowCount -gt 0}
    }
    else
    {
        return $tables | Where-Object {$_.RowCount -eq 0}
    }
}