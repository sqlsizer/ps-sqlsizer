function Copy-Data
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables,
        
        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Source -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $structure = [Structure]::new($info)
    $i = 0
    foreach ($table in $info.Tables)
    {
        $i += 1
        Write-Progress -Activity "Copying data" -PercentComplete (100 * ($i / ($info.Tables.Count))) -CurrentOperation "Table $($table.SchemaName).$($table.TableName)"

        if ($table.IsHistoric -eq $true)
        {
            continue
        }

        $isIdentity = $table.IsIdentity
        $schema = $table.SchemaName
        $tableName = $table.TableName
        
        $tableColumns = GetTableSelect -TableInfo $table -Raw $true -IgnoredTables $IgnoredTables
        $tableSelect = GetTableSelect -TableInfo $table -Raw $false -IgnoredTables $IgnoredTables

        $join = GetTableJoin -Database $Source -TableInfo $table -Structure $structure

        $sql = "INSERT INTO " +  $schema + ".[" +  $tableName + "] (" + $tableColumns + ") SELECT DISTINCT " + $tableSelect +  " FROM " + $Source + "." + $schema + ".[" +  $tableName + "] t"
        
        $sql = $sql + $join
        if ($isIdentity)
        {
            $sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON " + $sql + " SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF" 
        }
        $null = Execute-SQL -Sql $sql -Database $Destination -ConnectionInfo $ConnectionInfo 
    }
    
    Write-Progress -Activity "Copying data" -Completed
}

function GetTableSelect
{
    param (
        [bool]$Raw,
        [TableInfo]$TableInfo,
        [TableInfo2[]]$IgnoredTables
    )
    
    $select = ""
    $j = 0
    for ($i = 0; $i -lt $TableInfo.Columns.Count; $i++)
    {
        $column = $TableInfo.Columns[$i]
        $columnName = $column.Name

        if (($column.IsComputed -eq $true) -or ($column.IsGenerated -eq $true) -or ($column.DataType -eq "timestamp"))
        {
            continue
        }
        else
        {
            if ($j -gt 0)
            {
                $select += ","
            }

            $include = $true

            foreach ($fk in $TableInfo.ForeignKeys)
            {
                if ([TableInfo2]::IsIgnored($fk.Schema, $fk.Table, $ignoredTables) -eq $true)
                {
                    foreach ($fkColumn in $fk.FkColumns)
                    {
                        if ($fkColumn.Name -eq $columnName)
                        {
                            $include = $false
                            break
                        }
                    }
                }
            }

            if ($Raw)
            {
                $select +=  "[" + $columnName + "]"
            }
            else
            {
                if ($include)
                {
                    $select += Get-ColumnValue -columnName $columnName -dataType $column.DataType -prefix "t."
                }
                else
                {
                    $select += " NULL "
                }
            }

            $j += 1
        }
    }

    $select
}

# Function that creates join part of query
function GetTableJoin
{
     param (
        [string]$Database,
        [TableInfo]$TableInfo,
        [Structure]$Structure
     )

     $primaryKey = $TableInfo.PrimaryKey
     $processing = $Structure.GetProcessingName($Structure.Tables[$TableInfo])
     $where = " INNER JOIN $($Database).$($processing) p ON p.[Schema] = '" +  $Schema + "' and p.TableName = '" + $TableName + "' "

     $i = 0
     foreach ($column in $primaryKey)
     {
        $where += " AND p.Key" + $i + " = " + $column.Name + " " 
        $i += 1
     }

     $where
}
