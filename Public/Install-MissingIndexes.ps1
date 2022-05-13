function Install-MissingIndexes
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [Query[]]$Queries,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $reachableTables = Find-SubsetReachableTables -Database $Database -Queries $Queries -Connection $ConnectionInfo 

    $tablesGrouped = $info.Tables | Group-Object -Property SchemaName, TableName -AsHashTable -AsString

    foreach ($table in $reachableTables)
    {
        $tableInfo = $tablesGrouped[$table.SchemaName + ", "  + $table.TableName]

        foreach ($fk in $tableInfo.ForeignKeys)
        {
            $columns = ""
            $signature = ""

            foreach ($fkColumn in $fk.FkColumns)
            { 
                $pk = $tableInfo.PrimaryKey | Where-Object {$_.Name -eq $fkColumn.Name}

                if ($null -ne $pk)
                {
                    break
                }

                if ($columns -ne "")
                {
                    $columns += ","
                }
                $columns += $fkColumn.Name
                $signature += "_" + $fkColumn.Name 
            }

            if ($columns -ne "")
            {
                $indexName = "SqlSizer_$($table.SchemaName)_$($table.TableName)_$($signature)"
                $sql = "IF IndexProperty(OBJECT_ID('$($table.SchemaName).$($table.TableName)'), '$($indexName)', 'IndexId') IS NULL"
                $sql += " CREATE INDEX [$($indexName)] ON [$($table.SchemaName)].[$($table.TableName)] ($($columns))"
                $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
            }
        }
    }
}
