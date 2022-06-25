function Get-SubsetTableRows
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$false)]
        [bool]$AllColumns = $false,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $structure = [Structure]::new($info)
    
    foreach ($table in $info.Tables)
    {
        if (($table.SchemaName -eq $SchemaName) -and ($table.TableName -eq $TableName))
        {
            $processing = $structure.GetProcessingName($structure.Tables[$table])

            if ($AllColumns -eq $false)
            {
                $keys = ""
                for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
                {
                    $keys += "Key$($i) as $($table.PrimaryKey[$i].Name)"

                    if ($i -lt ($table.PrimaryKey.Count - 1))
                    {
                        $keys += ", "
                    }
                }

                $sql = "SELECT DISTINCT '$($table.TableName)' as SchemaName,'$($table.SchemaName)' as TableName, $($keys) FROM $($processing) WHERE [Table] = $($table.Id)"
                $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
                return $rows
            }
            else
            {
                $columns = ""

                for ($i = 0; $i -lt $table.Columns.Count; $i++)
                {
                    $include = $true
                    foreach ($fk in $table.ForeignKeys)
                    {
                        if ([TableInfo2]::IsIgnored($fk.Schema, $fk.Table, $ignoredTables) -eq $true)
                        {
                            foreach ($fkColumn in $fk.FkColumns)
                            {
                                if ($fkColumn.Name -eq $table.Columns[$i].Name)
                                {
                                    $include = $false
                                    break
                                }
                            }
                        }
                    }

                    if ($include)
                    {
                        $columns += "ISNULL(t.$($table.Columns[$i].Name), '') as $($table.Columns[$i].Name)"
                    }
                    else
                    {
                        $columns += "NULL as $($table.Columns[$i].Name)"
                    }
                    
                    if ($i -lt ($table.Columns.Count - 1))
                    {
                        $columns += ", "
                    }
                }

                $cond = ""
                for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
                {
                    $cond += "t.$($table.PrimaryKey[$i].Name) = p.Key$($i)"
                    if ($i -lt ($table.PrimaryKey.Count - 1))
                    {
                        $cond += " and "
                    }
                }
                $sql = "SELECT '$($table.SchemaName)' as SchemaName, '$($table.TableName)' as TableName, $($columns)
                        FROM $($processing) p 
                        INNER JOIN $($table.SchemaName).$($table.TableName) t ON $($cond)
                        INNER JOIN SqlSizer.Tables tt ON tt.[Schema] = '$($table.SchemaName)' AND tt.[TableName] = '$($table.TableName)'
                        WHERE p.[Table] = tt.Id"
                $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
                return $rows
            }
        }
    }

    return $null
}