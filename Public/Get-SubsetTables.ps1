function Get-SubsetTables
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Get-SubsetTableStatistics -Database $Database -Connection $ConnectionInfo | Where-Object {$_.RowCount -gt 0}
}