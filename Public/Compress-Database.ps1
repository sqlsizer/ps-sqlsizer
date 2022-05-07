function Compress-Database
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    
    Write-Progress -Activity "Shrinking database" -PercentComplete 0

    $sql = "DBCC SHRINKDATABASE ([" + ($Database) + "])"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    Write-Progress -Activity "Shrinking database" -Completed
}