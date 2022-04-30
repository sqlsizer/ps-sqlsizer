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

    $info = Get-DatabaseInfo -Database $Database -ConnectionInfo $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        $sql = "ALTER TABLE " + $table.SchemaName + "." + $table.TableName + " CHECK CONSTRAINT ALL"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $sql = "sp_msforeachtable 'ALTER TABLE ? ENABLE TRIGGER all'"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
}