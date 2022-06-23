function Format-Indexes
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    Write-Progress -Activity "Rebuilding indexes on database" -PercentComplete 0
    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    foreach ($table in $info.Tables)
    {
        $sql = "SET QUOTED_IDENTIFIER ON; ALTER INDEX ALL ON " + $table.SchemaName + "." + $table.TableName + " REBUILD "
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    Write-Progress -Activity "Rebuilding indexes on database" -Completed
}