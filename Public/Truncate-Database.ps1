function Truncate-Database
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
    $sql = "sp_msforeachtable 'ALTER TABLE ? DISABLE TRIGGER all'"
    $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        $sql = "ALTER TABLE " + $table.SchemaName + "." + $table.TableName + " NOCHECK CONSTRAINT ALL"
        $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    foreach ($table in $info.Tables)
    {
        $sql = "DELETE FROM " +  $table.SchemaName + "." + $table.TableName  
        $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
}