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

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Database -Connection $ConnectionInfo
    $structure = [Structure]::new($info)
    
    foreach ($table in $info.Tables)
    {
        if (($table.SchemaName -eq $SchemaName) -and ($table.TableName -eq $TableName))
        {
            $tableName = $structure.GetProcessingName($structure.Tables[$table])

            $keys = ""
            for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
            {
                $keys += "Key$($i) as $($table.PrimaryKey[$i].Name)"

                if ($i -lt ($table.PrimaryKey.Count - 1))
                {
                    $keys += ", "
                }
            }

            $sql = "SELECT DISTINCT '$($table.TableName)' as SchemaName,'$($table.SchemaName)' as TableName, $($keys) FROM $($tableName) WHERE [Schema] = '$($table.SchemaName)' AND TableName = '$($table.TableName)'"
            $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
            return $rows
        }
    }

    return $null
}