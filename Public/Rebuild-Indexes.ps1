function Rebuild-Indexes
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    Write-Progress -Activity "Rebuilding indexes on database" -PercentComplete 0
    
    $sql = "EXEC sp_msforeachtable 'SET QUOTED_IDENTIFIER ON; ALTER INDEX ALL ON ? REBUILD'"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    Write-Progress -Activity "Rebuilding indexes on database" -Completed
}