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
        foreach ($fk in $table.ForeignKeys)
        {
            if ($fk.Schema -eq $SchemaName)
            {
                $sql = "ALTER TABLE [" + $table.SchemaName + "].[" + $table.TableName + "] DROP CONSTRAINT IF EXISTS $($fk.Name)"
                $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
            }
        }
    }

    # drop tables
    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -eq $SchemaName)
        {
            foreach ($view in $table.Views)
            {
                $sql = "DROP VIEW [$($view.SchemaName)].[$($view.ViewName)]"
                $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
            }

            $sql = "DROP TABLE [$($table.SchemaName)].[$($table.TableName)]"
            $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }

    # drop all other views
    foreach ($view in $info.Views)
    {
        if ($view.SchemaName -eq $SchemaName)
        {
            $sql = "DROP VIEW if exists [$($view.SchemaName)].[$($view.ViewName)]"
            $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }

    # drop schema
    $tmp = "DROP SCHEMA IF EXISTS $SchemaName"
    $null = Invoke-SqlcmdEx -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
}