function Get-SubsetTables
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Get-SubsetTableStatistics -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo | Where-Object {$_.RowCount -gt 0}
}