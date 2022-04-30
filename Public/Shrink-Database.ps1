function Shrink-Database
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    $sql = "DBCC SHRINKDATABASE ([" + ($Database) + "])"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
}