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

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Database -Connection $ConnectionInfo
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

                $sql = "SELECT DISTINCT '$($table.TableName)' as SchemaName,'$($table.SchemaName)' as TableName, $($keys) FROM $($processing) WHERE [Schema] = '$($table.SchemaName)' AND TableName = '$($table.TableName)'"
                $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
                return $rows
            }
            else
            {
                $columns = ""

                for ($i = 0; $i -lt $table.Columns.Count; $i++)
                {
                    $columns += "t.$($table.Columns[$i].Name)"
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
                $sql = "SELECT '$($table.TableName)' as SchemaName, '$($table.SchemaName)' as TableName, $($columns)
                        FROM $($processing) p 
                        INNER JOIN $($table.SchemaName).$($table.TableName) t ON $($cond)
                        WHERE p.[Schema] = '$($table.SchemaName)' AND p.TableName = '$($table.TableName)'"
                $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
                return $rows
            }
        }
    }

    return $null
}