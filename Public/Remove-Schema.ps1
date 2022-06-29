function Remove-Schema
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Database -Connection $ConnectionInfo

    # remove fks from schema
    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -ne $SchemaName)
        {
            continue
        }
        foreach ($fk in $table.ForeignKeys)
        {
            $sql = "ALTER TABLE [" + $table.SchemaName + "].[" + $table.TableName + "] DROP CONSTRAINT IF EXISTS $($fk.Name)"
            $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }
    
    # drop tables
    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -eq $SchemaName)
        {
            $sql = "DROP TABLE [$($table.SchemaName)].[$($table.TableName)]"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }

    # drop schema
    $tmp = "DROP SCHEMA IF EXISTS $SchemaName"
    $null = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
}