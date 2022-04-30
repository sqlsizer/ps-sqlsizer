function Disable-IntegrityChecks
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

    $sql = "sp_msforeachtable 'ALTER TABLE ? DISABLE TRIGGER all'"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        $sql = "ALTER TABLE " + $table.SchemaName + "." + $table.TableName + " NOCHECK CONSTRAINT ALL"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
}