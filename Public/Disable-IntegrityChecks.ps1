function Disable-IntegrityChecks
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

    Write-Progress -Activity "Disabling integrity checks on database" -PercentComplete 0 
    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    foreach ($table in $info.Tables)
    {
        $sql = "ALTER TABLE " + $table.SchemaName + "." + $table.TableName + " DISABLE TRIGGER all"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $i = 0
    foreach ($table in $info.Tables)
    {
        $i += 1
        Write-Progress -Activity "Disabling integrity checks on database" -PercentComplete (100 * ($i / $info.Tables.Count))

        $sql = "ALTER TABLE " + $table.SchemaName + "." + $table.TableName + " NOCHECK CONSTRAINT ALL"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
    Write-Progress -Activity "Disabling integrity checks on database" -Completed
}