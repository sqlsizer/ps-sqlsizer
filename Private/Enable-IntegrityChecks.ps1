function Enable-IntegrityChecks
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-TablesInfo -Database $Database -ConnectionInfo $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        $sql = "ALTER TABLE " + $table.SchemaName + "." + $table.TableName + " CHECK CONSTRAINT ALL"
        $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $sql = "sp_msforeachtable 'ALTER TABLE ? ENABLE TRIGGER all'"
    $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    $sql = "DBCC SHRINKDATABASE ([" + ($Database) + "])"
   $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
}