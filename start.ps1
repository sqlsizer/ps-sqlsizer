#-------------------------------------------
# Logic
#-------------------------------------------


# Function to execute SQL on database
function ExecuteSQL
{
    param
    (
        [string]$Sql,
        [string]$Database
    )
    Write-Host "--"
    Write-Host $Sql

    $time = Measure-Command {
     $result = Invoke-Sqlcmd -Query $Sql -ServerInstance $server -Database $Database -Username $login -Password $password -QueryTimeout 600000
    }
    Write-Host $time
    $result
}


# Function to initialize SqlSizer tables and indexes
function Init
{
    $tmp = "IF OBJECT_ID('SqlSizer.Slice') IS NOT NULL  
        Drop Table SqlSizer.Slice"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "IF OBJECT_ID('SqlSizer.ProcessingStats') IS NOT NULL  
        Drop Table SqlSizer.ProcessingStats"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "IF OBJECT_ID('SqlSizer.Processing') IS NOT NULL
        Drop Table SqlSizer.Processing"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "DROP SCHEMA IF EXISTS SqlSizer"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "CREATE SCHEMA SqlSizer"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "CREATE TABLE SqlSizer.Slice (Id int primary key identity(1,1), Key1 varchar(32), Key2 varchar(32), Key3 varchar(32), Key4 varchar(32), Depth int NULL, ProcessingId int NULL)"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "CREATE TABLE SqlSizer.Processing (Id int primary key identity(1,1), [Schema] varchar(64), TableName varchar(64), Key1 varchar(32), Key2 varchar(32), Key3 varchar(32), Key4 varchar(32), [type] int, [status] int, [depth] int, [parent] int, initial bit NULL)"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "CREATE TABLE SqlSizer.ProcessingStats (Id int primary key identity(1,1), [Schema] varchar(64), TableName varchar(64), ToProcess int, Processed int)"
    ExecuteSQL -Sql $tmp -Database $database

    $tmp = "CREATE UNIQUE INDEX [Index] ON SqlSizer.Slice ([Key1] ASC, [Key2] ASC, [Key3] ASC, [Key4] ASC, [ProcessingId] ASC)"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "CREATE UNIQUE INDEX [Index] ON SqlSizer.[Processing] ([Schema] ASC, TableName ASC, [Key1] ASC, [Key2] ASC, [Key3] ASC, [Key4] ASC, [type] ASC, [parent] ASC)"
    ExecuteSQL -Sql $tmp -Database $database
    
    $tmp = "TRUNCATE TABLE SqlSizer.Processing"
    ExecuteSQL -Sql $tmp -Database $database
}



# Function that returns datatype of the column
function GetType
{
    param 
    (
        [string]$schema,
        [string]$tableName,
        [string]$columnName,
        [System.Data.DataRow[]]$rows
    )

    foreach ($row in $rows)
    {
        if (($row["table"] -eq $tableName) -and ($row["schema"] -eq $schema) -and ($row["column"] -eq $columnName))
        {
            $row["dataType"]
            break
        }
    }

    $null
}

# Function that return expression for column
function GetColumnValue
{
    param 
    (
        [string]$schema,
        [string]$tableName,
        [string]$columnName,
        [string]$prefix,
        [System.Data.DataRow[]]$rows
    )

    $type = GetType -schema $schema -tableName $tableName -columnName $columnName -rows $rows

    if ($type -eq "hierarchyid")
    {
        "CONVERT(nvarchar(max), " + $prefix + $columnName + ")"
    }
    else 
    {
        if ($type -eq "xml")
        {
            "CONVERT(nvarchar(max), " + $prefix + $columnName + ")"
        }
        else
        {
            "[" + $columnName + "]"
        }
    }
}


# Function that is able to quote values if the value needs that
function GetValue
{
    param 
    (
        [string]$schema,
        [string]$tableName,
        [string]$columnName,
        [string]$value,
        [System.Data.DataRow[]]$rows
    )

    $type = GetType -schema $schema -tableName $tableName -columnName $columnName -rows $rows

    if (($type -eq "varchar") -or ($type -eq "nvarchar") -or ($type -eq "date") -or ($type -eq "datetime") -or ($type -eq "nchar") -or ($type -eq "char"))
    {
        "'" + $value + "'"
    }
    else
    {
        $value
    }
}


# Function that Intialize statistics (how many records to process per table)
function InitStats
{
    # init stats
    $sql = "INSERT INTO SqlSizer.ProcessingStats([Schema], [TableName], [ToProcess], [Processed])
            SELECT [Schema], TableName, COUNT(*), 0
            FROM [SqlSizer].[Processing]
            GROUP BY [Schema], TableName"
    $_ = ExecuteSQL -Sql $sql -Database $database

    $sql = Get-Content -Path "Queries\Tables.sql" -Raw
    $tables = ExecuteSQL -Sql $sql -Database $database

    foreach ($table in $tables)
    {
        if ($table["schema"] -ne "SqlSizer")
        {
            $sql = "IF NOT EXISTS(SELECT * FROM SqlSizer.ProcessingStats WHERE [Schema] = '" + $table["schema"] + "' and TableName = '" + $table["table"] + "') INSERT INTO SqlSizer.ProcessingStats VALUES('" +  $table["schema"] + "', '" + $table["table"] + "', 0, 0)"
            $_ = ExecuteSQL -Sql $sql -Database $database
        }
    }

}

# MAIN FUNCTION (Subsetting logic)
function FindRelated
{
    $primaryKeysSql = Get-Content -Path "Queries\PrimaryKeys.sql" -Raw
    $foreignKeysSql = Get-Content -Path "Queries\ForeignKeys.sql" -Raw
    
    $primaryKeys = ExecuteSQL -Sql $primaryKeysSql -Database $database
    $foreignKeys = ExecuteSQL -Sql $foreignKeysSql -Database $database
    
    $columnsSql = Get-Content -Path "Queries\Columns.sql" -Raw
    $columns = ExecuteSQL -Sql $columnsSql -Database $database

    $processed = @{ }
    $result = @()

    $_ = InitStats    
    
    while ($true)
    { 
        $q = "SELECT TOP 1 p.[Schema], p.TableName, Type  FROM SqlSizer.Processing p JOIN SqlSizer.ProcessingStats ps ON p.[Schema] = ps.[Schema] and p.[TableName] = ps.[TableName] WHERE Status = 0 ORDER BY ToProcess DESC"
        $first = ExecuteSQL -Sql $q -Database $database
    
        if ($first -eq $null)
        {
            break
        }
    
        $q = "TRUNCATE TABLE SqlSizer.Slice"
        $_ = ExecuteSQL -Sql $q -Database $database

    
        $q = "INSERT INTO SqlSizer.Slice " +  "SELECT DISTINCT Key1, Key2, Key3, Key4, Depth, Id FROM SqlSizer.Processing WHERE Status = 0 AND Type = " + $first.Type + " AND TableName = '" + $first.TableName + "' and [Schema] = '" + $first.Schema + "'"
        $_ = ExecuteSQL -Sql $q -Database $database
    
        $primaryKey = GetPrimaryKey -Schema $first.Schema -TableName $first.TableName -PrimaryKeys $primaryKeys
        $foreignKeysForTable = GetForeignKeys -Schema $first.Schema -TableName $first.TableName -ForeignKeys $foreignKeys
        $referencesToTable = GetReferencedKeys -Schema $first.Schema -TableName $first.TableName -ForeignKeys $foreignKeys
        
        # Red color - 1
        if ($first.Type -eq $red) 
        {
           $foreignKeysForTableGrouped = $foreignKeysForTable | Group-Object -Property fk_name
           foreach ($item in $foreignKeysForTableGrouped)
           {
               $group = $item.Group

               $tableSchema = $group.schema2_name
               $table = $group.referenced_table
               $fkTableSchema = $group.schema_name
               $fkTable = $group.table

               if ($group.Count -eq 2)
               {
                    $fkTableSchema = $fkTableSchema.split(' ')[0]
                    $fkTable = $fkTable.split(' ')[0]
                    $tableSchema = $tableSchema.split(' ')[0]
                    $table = $table.split(' ')[0]
               }

               $primaryKey = GetPrimaryKey -Schema $fkTableSchema -TableName $fkTable -PrimaryKeys $primaryKeys
               $fkColumns = $group | Select-Object -Property column
               $join = ""
               $where = ""
               
               if ($primaryKey.Count -eq 1)
               {
                   $join =  " INNER JOIN SqlSizer.Slice s ON s.Key1 = b." + $primaryKey
               }

               if ($primaryKey.Count -eq 2)
               {
                   $join =  " INNER JOIN SqlSizer.Slice s ON s.Key1 = b." + $primaryKey[0] + " and s.Key2 = b." + $primaryKey[1] 
               }

               if ($primaryKey.Count -eq 3)
               {
                   $join = " INNER JOIN SqlSizer.Slice s ON s.Key1 = b." + $primaryKey[0] + " and s.Key2 = b." + $primaryKey[1] + " and s.Key3 = b." + $primaryKey[2]                   
               }

               if ($primaryKey.Count -eq 4)
               {
                   $join = " INNER JOIN SqlSizer.Slice s ON s.Key1 = b." + $primaryKey[0] + " and s.Key2 = b." + $primaryKey[1] + " and s.Key3 = b." + $primaryKey[2] + " and s.Key4 = b." + $primaryKey[3]
               }

               if ($group.Count -eq 1)
               {
                    $fkColumn = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns.column -rows $columns
                    $sql = "SELECT b." +  $fkColumn + " as val, NULL as val2, NULL as val3, NULL as val4, s.Depth as Depth, s.ProcessingId as ProcessingId FROM " + $fkTableSchema + "." + $fkTable  + " b "
                    $where = " WHERE b." + $fkColumn + " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.parent = s.ProcessingId and p.[Schema] = '" + $tableSchema + "' and p.TableName = '" + $table + "' and p.Key1 = b." + $fkColumn + ")"

                    $sql = $sql + $join
                    $sql = $sql + $where
               }
               
               if ($group.Count -eq 2)
               {
                   $fkColumn = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[0].column -rows $columns
                   $fkColumn2 = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[1].column -rows $columns
                   $sql = "SELECT b." +  $fkColumn + " as val, b." +  $fkColumn2 + " as val2, NULL as val3, NULL as val4, s.Depth as Depth, s.ProcessingId as ProcessingId FROM " + $fkTableSchema + "." + $fkTable  + " b "
                   $where = " WHERE b." + $fkColumn + " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.parent = s.ProcessingId and p.[Schema] = '" + $tableSchema + "' and p.TableName = '" + $table + "' and p.Key1 = b." + $fkColumn + " and p.Key2 = b." + $fkColumn2 + ")"
                   
                   $sql = $sql + $join
                   $sql = $sql + $where
               }

               if ($group.Count -eq 3)
               {
                   $fkColumn = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[0].column -rows $columns
                   $fkColumn2 = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[1].column -rows $columns
                   $fkColumn3 = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[2].column -rows $columns

                   $sql = "SELECT b." +  $fkColumn + " as val, b." +  $fkColumn2 + " as val2,  b." +  $fkColumn3 + " as val3, NULL as val4, s.Depth as Depth, s.ProcessingId as ProcessingId FROM " + $fkTableSchema + "." + $fkTable  + " b "
                   $where = " WHERE b." + $fkColumn + " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.parent = s.ProcessingId and p.[Schema] = '" + $tableSchema + "' and p.TableName = '" + $table + "' and p.Key1 = b." + $fkColumn + " and p.Key2 = b." + $fkColumn2 + " and p.Key3 = b." + $fkColumn3 + ")"
                   $sql = $sql + $join
                   $sql = $sql + $where 
               }
               
               if ($group.Count -eq 4)
               {
                   $fkColumn = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[0].column -rows $columns
                   $fkColumn2 = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[1].column -rows $columns
                   $fkColumn3 = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[2].column -rows $columns
                   $fkColumn4 = GetColumnValue -schema $tableSchema -tableName $table -columnName $fkColumns[3].column -rows $columns

                   $sql = "SELECT b." +  $fkColumn + " as val, b." +  $fkColumn2 + " as val2,  b." +  $fkColumn3 + " as val3, b." +  $fkColumn4 + " as val4, s.Depth as Depth, s.ProcessingId as ProcessingId FROM " + $fkTableSchema + "." + $fkTable  + " b "
                   $where = " WHERE b." + $fkColumn + " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.parent = s.ProcessingId and p.[Schema] = '" + $tableSchema + "' and p.TableName = '" + $table + "' and p.Key1 = b." + $fkColumn + " and p.Key2 = b." + $fkColumn2 + " and p.Key3 = b." + $fkColumn3 + " and p.Key4 = b." + $fkColumn4 + ")"
                   $sql = $sql + $join
                   $sql = $sql + $where
               }

               
               $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $tableSchema + "', '"  +  $table + "'"
               
               if ($group.Count -eq 1)
               {
                   $insert = $insert + ", x.val, NULL, NULL, NULL, 1, 0, x.Depth + 1, x.ProcessingId, 0 FROM (" + $sql + ") x"
               }

               if ($group.Count -eq 2)
               {
                   $insert = $insert + ", x.val, x.val2, NULL, NULL, 1, 0,  x.Depth + 1, x.ProcessingId, 0 FROM (" + $sql + ") x"
               }

               if ($group.Count -eq 3)
               {
                   $insert = $insert + ", x.val, x.val2, x.val3, NULL, 1, 0,  x.Depth + 1, x.ProcessingId, 0 FROM (" + $sql + ") x"
               }

               if ($group.Count -eq 4)
               {
                   $insert = $insert + ", x.val, x.val2, x.val3, x.val4, 1, 0, x.Depth + 1, x.ProcessingId, 0 FROM (" + $sql + ") x"
               }

               $insert = $insert + " SELECT @@ROWCOUNT AS Count"
               $results = ExecuteSQL -Sql $insert -Database $database

               $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $tableSchema + "' and [TableName] = '" +  $table + "'"
               $_ = ExecuteSQL -Sql $q -Database $database
            }
        }      

        # Green - 2
        if ($first.Type -eq $green) 
        {
           $referencesToTableGrouped = $referencesToTable | Group-Object -Property fk_name

           foreach ($item in $referencesToTableGrouped)
           {
               $group = $item.Group
               $tableSchema = $group.schema_name
               $table = $group.table

               $primaryKey = GetPrimaryKey -Schema $tableSchema -TableName $table -PrimaryKeys $primaryKeys
               $fkColumns = $group | Select-Object -Property column

               $from = ""

               if ($group.Count -eq 1)
               {
                   $from = $tableSchema + "." + $table + " z INNER JOIN SqlSizer.Slice p ON z." + $fkColumns[0].column + " = p.Key1"
               }

               if ($group.Count -eq 2)
               {
                   $from = $tableSchema + "." + $table + " z INNER JOIN SqlSizer.Slice p ON z." + $fkColumns[0].column + " = p.Key1 and z." + $fkColumns[1].column + " = p.Key2"
               }

               if ($group.Count -eq 3)
               {
                   $from = $tableSchema + "." + $table + " z INNER JOIN SqlSizer.Slice p ON z." + $fkColumns[0].column + " = p.Key1 and z." + $fkColumns[1].column + " = p.Key2 and z." + $fkColumns[2].column + "= p.Key3"
               }

               if ($group.Count -eq 4)
               {
                   $from = $tableSchema + "." + $table + " z INNER JOIN SqlSizer.Slice p ON z." + $fkColumns[0].column + " = p.Key1 and z." + $fkColumns[1].column + " = p.Key2 and z." + $fkColumns[2].column + "= p.Key3 and z." + $fkColumns[3].column + " = p.Key4"
               }

               if ($primaryKey.Count -eq 1)
               {
                   $primaryKey = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey) -prefix "z." -rows $columns
                   $sql = "SELECT DISTINCT " + $primaryKey + " as val, NULL as val2, NULL as val3, NULL as val4, p.Depth, p.ProcessingId FROM " + $from
                   $sql = $sql + " AND NOT EXISTS(SELECT * FROM SqlSizer.Processing WHERE [Type] = 3 and parent = p.ProcessingId and [Schema] = '" + $tableSchema + "' and TableName = '" + $table + "' and  Key1 = " + $primaryKey + ")"
               }
            
               if ($primaryKey.Count -eq 2)
               {
                   $primaryKey[0] = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey[0]) -prefix "z." -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey[1]) -prefix "z." -rows $columns
                   $sql = "SELECT DISTINCT " +  $primaryKey[0] + " as val, " +  $primaryKey[1] + " as val2, NULL as val3, NULL as val4, p.Depth, p.ProcessingId FROM " + $from
                   $sql = $sql + " AND NOT EXISTS(SELECT * FROM SqlSizer.Processing WHERE [Type] = 3 and parent = p.ProcessingId and [Schema] = '" + $tableSchema + "' and TableName = '" + $table + "' and  Key1 = " + $primaryKey[0] + " and Key2 = " + $primaryKey[1] + ")"
               }

               if ($primaryKey.Count -eq 3)
               {
                   $primaryKey[0] = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey[0]) -prefix "z." -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $tableSchema -tableName $table -columnName  ($primaryKey[1]) -prefix "z." -rows $columns
                   $primaryKey[2] = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey[2]) -prefix "z." -rows $columns
                   $sql = "SELECT DISTINCT " +  $primaryKey[0] + " as val, " +  $primaryKey[1] + " as val2, " + $primaryKey[2] + " as val3, NULL as val4, p.Depth, p.ProcessingId FROM " + $from
                   $sql = $sql + " AND NOT EXISTS(SELECT * FROM SqlSizer.Processing WHERE [Type] = 3 and parent = p.ProcessingId and [Schema] = '" + $tableSchema + "' and TableName = '" + $table + "' and  Key1 = " + $primaryKey[0] + " and Key2 = " + $primaryKey[1] + " and Key3 = " + $primaryKey[2] + ")"
               }
               
               if ($primaryKey.Count -eq 4)
               {
                   $primaryKey[0] = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey[0]) -prefix "z." -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $tableSchema -tableName $table -columnName  ($primaryKey[1]) -prefix "z." -rows $columns
                   $primaryKey[2] = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey[2]) -prefix "z." -rows $columns
                   $primaryKey[3] = GetColumnValue -schema $tableSchema -tableName $table -columnName ($primaryKey[3]) -prefix "z." -rows $columns
                   $sql ="SELECT DISTINCT " + $primaryKey[0] + " as val, " + $primaryKey[1] + " as val2, " + $primaryKey[2] + " as val3, " + $primaryKey[3] + " as val4, p.Depth, p.ProcessingId FROM " + $from
                   $sql = $sql + " AND NOT EXISTS(SELECT * FROM SqlSizer.Processing WHERE [Type] = 3 and parent = p.ProcessingId and [Schema] = '" + $tableSchema + "' and TableName = '" + $table + "' and  Key1 = " + $primaryKey[0] + " and Key2 = " + $primaryKey[1] + " and Key3 = " + $primaryKey[2] + " and Key4 = " + $primaryKey[3] + ")"
               }                
                
               $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $tableSchema + "', '" + $table + "', x.val, x.val2, x.val3, x.val4, 3, 0, x.Depth + 1, x.ProcessingId, 0 FROM (" + $sql + ") x SELECT @@ROWCOUNT AS Count"
               $results = ExecuteSQL -Sql $insert -Database $database

               # update stats
               $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $tableSchema + "' and [TableName] = '" +  $table + "'"
               $_ = ExecuteSQL -Sql $q -Database $database
           }
        }
        
        # Yellow - 3 -> Split into Red and Green
        if ($first.Type -eq $yellow)
        {
            # insert 
            $q = "INSERT INTO SqlSizer.Processing " +  "SELECT '" + $first.Schema + "', '" +  $first.TableName +  "', s.Key1, s.Key2, s.Key3, s.Key4, 1, 0, s.Depth, s.ProcessingId, 0 FROM SqlSizer.Slice s" + " WHERE NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.[Schema] = '" + $first.Schema + "' and p.[TableName] = '" + $first.TableName + "' and (p.Key1 = s.Key1 OR s.Key1 IS NULL) and (p.Key2 = s.Key2 OR s.Key2 IS NULL) and (p.Key3 = s.Key3 OR s.Key3 IS NULL) and (p.Key4 = s.Key4 OR s.Key4 IS NULL)) SELECT @@ROWCOUNT AS Count"
            $results = ExecuteSQL -Sql $q -Database $database

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $first.Schema + "' and [TableName] = '" +  $first.TableName + "'"
            $_ = ExecuteSQL -Sql $q -Database $database

            # insert 
            $q = "INSERT INTO SqlSizer.Processing " +  "SELECT '" + $first.Schema + "', '" +  $first.TableName +  "', s.Key1, s.Key2, s.Key3, s.Key4, 2, 0, s.Depth, s.ProcessingId, 0 FROM SqlSizer.Slice s" + " WHERE NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 2 and p.[Schema] = '" + $first.Schema + "' and p.[TableName] = '" + $first.TableName + "' and (p.Key1 = s.Key1 OR s.Key1 IS NULL) and (p.Key2 = s.Key2 OR s.Key2 IS NULL) and (p.Key3 = s.Key3 OR s.Key3 IS NULL) and (p.Key4 = s.Key4 OR s.Key4 IS NULL)) SELECT @@ROWCOUNT AS Count"
            $results = ExecuteSQL -Sql $q -Database $database

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $first.Schema + "' and [TableName] = '" +  $first.TableName + "'"
            $_ = ExecuteSQL -Sql $q -Database $database
        }
        
        # Update status
        $q = "UPDATE p SET Status = 1 FROM SqlSizer.Processing p WHERE [Schema] = '" + $first.Schema + "' and TableName = '" + $first.TableName + "' and [Type] = " + $first.Type + " and Status = 0 and EXISTS(SELECT * FROM SqlSizer.Slice s WHERE (p.Key1 = s.Key1 OR s.Key1 IS NULL) and (p.Key2 = s.Key2 OR s.Key2 IS NULL) and (p.Key3 = s.Key3 OR s.Key3 IS NULL) and (p.Key4 = s.Key4 OR s.Key4 IS NULL)) SELECT @@ROWCOUNT AS Count"
        $results = ExecuteSQL -Sql $q -Database $database

        # update stats
        $q = "UPDATE SqlSizer.ProcessingStats SET Processed = Processed + " + $results.Count + ", ToProcess = ToProcess - " + $results.Count +  " WHERE [Schema] = '" +  $first.Schema + "' and [TableName] = '" +  $first.TableName + "'"
        $_ = ExecuteSQL -Sql $q -Database $database
    }
    
    $q = "SELECT DISTINCT [Schema], TableName, Key1, Key2, Key3, Key4 FROM SqlSizer.Processing"
    ExecuteSQL -Sql $q -Database $database
}


# Function that returns primary key for the table
function GetPrimaryKey
{
    param (
        [string]$Schema,
        [string]$TableName,
        [System.Data.DataRow[]]$PrimaryKeys
    )

    $key = @()

    foreach ($row in $PrimaryKeys)
    {
        if (($row["table"] -eq $TableName) -and ($row["schema"] -eq $Schema))
        {  
           $key += $row.column
        }
    }

    $key
}

# Function that returns foreign keys for the table
function GetForeignKeys
{
    param (
        [string]$Schema,
        [string]$TableName,
        [System.Data.DataRow[]]$ForeignKeys
    )

    $rows = @()

    foreach ($fRow in $ForeignKeys)
    {
        if (($fRow["table"] -eq $TableName) -and ($fRow["schema_name"] -eq $Schema))
        { 
          $rows += $fRow
        }
    }

    $rows
}

# Function that returns foreign keys to the table
function GetReferencedKeys
{
    param (
        [string]$Schema,
        [string]$TableName,
        [System.Data.DataRow[]]$ForeignKeys
    )

    $rows = @()

    foreach ($fRow in $ForeignKeys)
    {
        if (($fRow["referenced_table"] -eq $TableName) -and ($fRow["schema2_name"] -eq $Schema))
        { 
          $rows += $fRow
        }
    }

    $rows
}

# Function that quote if needed
function QuoteIfNeeded
{
    param (
        [string]$val
    )
    
    if ($val -eq 'NULL')
    {
        return $val
    }

    if ($val -match "^\d+$")
    {
        return $val
    }
    else
    {
        return "'" + $val + "'"
    }
}

# Function that add data to Processing table
function AddToProcessing
{
    param (
        [string]$schema,
        [string]$table,
        [string]$key,
        [string]$key2 = 'NULL',
        [string]$key3 = 'NULL',
        [string]$key4 = 'NULL',
        [int]$type
    )

    if ([string]::IsNullOrEmpty($key1)) { $key1 = 'NULL' }
    if ([string]::IsNullOrEmpty($key2)) { $key2 = 'NULL' }
    if ([string]::IsNullOrEmpty($key3)) { $key3 = 'NULL' }
    if ([string]::IsNullOrEmpty($key4)) { $key4 = 'NULL' }

    $q = "INSERT INTO SqlSizer.Processing VALUES('" + $schema + "','" + $table + "'," + (QuoteIfNeeded -Val $key) + "," + (QuoteIfNeeded -Val $key2)  + "," +(QuoteIfNeeded -Val $key3) + "," +(QuoteIfNeeded -Val $key4) + "," + $type + ", 0, 0, NULL, 1 )"
    ExecuteSQL -Sql $q -Database $database
}

# -----------------------------------------


# Function that make a copy of the database
function CopyDatabase
{
   $_ = Copy-DbaDatabase -Database $database -SourceSqlCredential $cred -DestinationSqlCredential $cred -Source $server -Destination $server -Prefix $prefix -BackupRestore -SharedPath (Get-DbaDefaultPath -SqlCredential $cred -SqlInstance $server).Backup 
}


# Function that truncates the tables in the database
function Truncate
{
    $sql = Get-Content -Raw -Path "Queries\Tables.sql"
    $tables = ExecuteSQL -Sql $sql -Database ($prefix + $database)

    $sql = "sp_msforeachtable 'ALTER TABLE ? DISABLE TRIGGER all'"
    $_ = ExecuteSQL -Sql $sql -Database ($prefix + $database)

    foreach ($table in $tables)
    {
        $sql = "ALTER TABLE " + $table["schema"] + "." + $table["table"] + " NOCHECK CONSTRAINT ALL"
        $_ = ExecuteSQL -Sql $sql -Database ($prefix + $database)
    }

    foreach ($table in $tables)
    {
        $sql = "DELETE FROM " + $table["schema"] + "." + $table["table"]        
        $_ = ExecuteSQL -Sql $sql -Database ($prefix + $database)
    }
}

# Function that enables reference checks on all tables
function EnableChecks
{
    $sql = Get-Content -Raw -Path "Queries\Tables.sql"
    $tables = ExecuteSQL -Sql $sql -Database ($prefix + $database)


    foreach ($table in $tables)
    {
        $sql = "ALTER TABLE " + $table["schema"] + "." + $table["table"] + " CHECK CONSTRAINT ALL"
        $_ = ExecuteSQL -Sql $sql -Database ($prefix + $database)
    }

    $sql = "sp_msforeachtable 'ALTER TABLE ? ENABLE TRIGGER all'"
    $_ = ExecuteSQL -Sql $sql -Database ($prefix + $database)

    $sql = "DBCC SHRINKDATABASE ([" + ($prefix + $database) + "])"
    $_ = ExecuteSQL -Sql $sql -Database ($prefix + $database)
}


# Function that returns whether the column in computed
function IsComputed
{
     param (
        [string]$Schema,
        [string]$TableName,
        [string]$ColumnName,
        [System.Data.DataRow[]]$Computed
    )

    $result = $false

    foreach ($row in $Computed)
    {
        if (($row["table"] -eq $TableName) -and ($row["schema"] -eq $Schema) -and ($row["column"] -eq $ColumnName))
        {  
           $result = $true
        }
    }

    $result
}

# Function that returns if the table has identity column
function HasIdentity
{
     param (
        [string]$Schema,
        [string]$TableName,
        [System.Data.DataRow[]]$Identifies
    )

    $result = $false

    foreach ($row in $Identifies)
    {
        if (($row["table"] -eq $TableName) -and ($row["schema"] -eq $Schema))
        {  
           $result = $true
        }
    }

    $result
}

# Function that returns list of tables that has identity column
function GetTablesWithIdentityInsert
{
     param (
        [string]$server,
        [string]$database
    )

    $sql = Get-Content -Raw -Path "Queries\Identity.sql"
    $tables = ExecuteSQL -Sql $sql -Database $database
    
    $tables
}

# Function that copy data (found subset) from source database to the subset database
function CopyData
{
    param (
        [string]$source,
        [string]$destination,
        [Object]$related
    )
    
    $columnsSql = Get-Content -Path "Queries\Columns.sql" -Raw
    $columns = ExecuteSQL -Sql $columnsSql -Database $database
    
    $identityTables = GetTablesWithIdentityInsert -server $server -database $source
    
    $computedSql = Get-Content -Path "Queries\Computed.sql" -Raw
    $computed =  ExecuteSQL -Sql $computedSql -Database $database

    $primaryKeysSql = Get-Content -Path "Queries\PrimaryKeys.sql" -Raw
    $primaryKeys = ExecuteSQL -Sql $primaryKeysSql -Database $database

    $groups = $related | Group-Object -Property Schema, TableName
    foreach ($group in $groups)
    {
        $groupName = $group.Name
        $schema = $groupName.split(',')[0].trim(' ')
        $tableName = $groupName.split(',')[1].trim(' ')
       
        $tableColumns = GetTableSelect -Columns $columns -TableName $tableName -Schema $schema -Computed $computed -Raw $true
        $tableSelect = GetTableSelect -Columns $columns -TableName $tableName -Schema $schema -Computed $computed -Raw $false

        $where = GetTableWhere -Columns $columns -TableName $tableName -Schema $schema -PrimaryKeys $primaryKeys

        $isIdentity = HasIdentity -Schema $schema -TableName $tableName -Identifies $identityTables

        $sql = "INSERT INTO " +  $schema + ".[" +  $tableName + "] (" + $tableColumns + ") SELECT " + $tableSelect +  " FROM " + $source + "." + $schema + ".[" +  $tableName + "]"
        
        $sql = $sql + $where
        if ($isIdentity)
        {
            $sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON " + $sql + " SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF" 
        }
        $_ = ExecuteSQL -Sql $sql -Database $destination
   }
}

# Function that creates a select part of query
function GetTableSelect
{
    param (
        [string]$Schema,
        [string]$TableName,
        [System.Data.DataRow[]]$Columns,
        [System.Data.DataRow[]]$Computed,
        [bool]$Raw
    )

    $select = ""

    $i = 0


    foreach ($row in $Columns)
    {
        if (($row["table"] -eq $TableName) -and ($row["schema"] -eq $Schema))
        {  
           $isComputed = IsComputed -Schema $Schema -TableName $TableName -ColumnName $row["column"] -Computed $Computed

           if ($isComputed)
           {
              continue
           }

           if ($i -gt 0)
           {
              $select += ","
           }

           if ($raw)
           {
              $select += "[" + $row["column"] + "]"
           }
           else
           {
              $select += GetColumnValue -schema $Schema -tableName $TableName -columnName $row["column"] -rows $columns
           }
           
           $i += 1
        }
    }

    $select
}


# Function that creates a where part of query
function GetTableWhere
{
     param (
        [string]$Schema,
        [string]$TableName,
        [System.Data.DataRow[]]$PrimaryKeys
     )

     $primaryKey = GetPrimaryKey -Schema $Schema -TableName $TableName -PrimaryKeys $PrimaryKeys

     $Key1 = (GetValue -tableName $TableName -columnName $primaryKey -value $Key1 -schema $Schema -rows $PrimaryKeys)

     if ($primaryKey.Count -gt 1)
     {
        $Key2 = (GetValue -tableName $TableName -columnName $primaryKey[1] -value $Key2 -schema $Schema -rows $PrimaryKeys)
     }

     if ($primaryKey.Count -gt 2)
     {
        $Key3 = (GetValue -tableName $TableName -columnName $primaryKey[2] -value $Key3 -schema $Schema -rows $PrimaryKeys)
     }

     if ($primaryKey.Count -gt 3)
     {
        $Key4 = (GetValue -tableName $TableName -columnName $primaryKey[3] -value $Key4 -schema $Schema -rows $PrimaryKeys)
     }
     
     if ($primaryKey.Count -eq 1)
     {
         " WHERE EXISTS(SELECT * FROM " + $database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey  + ")"
     }
     
     if ($primaryKey.Count -eq 2)
     {
        " WHERE EXISTS(SELECT * FROM " + $database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey[0] + " AND Key2 = " + $primaryKey[1] + ")"
     }

     if ($primaryKey.Count -eq 3)
     {
        " WHERE EXISTS(SELECT * FROM " + $database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey[0] + " AND Key2 = " + $primaryKey[1] + " AND Key3 = " + $primaryKey[2] + ")"
     }

     if ($primaryKey.Count -eq 4)
     {
        " WHERE EXISTS(SELECT * FROM " + $database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey[0] + " AND Key2 = " + $primaryKey[1] + " AND Key3 = " + $primaryKey[2] + " AND Key4 = " + $primaryKey[3] + ")"
     }
}


# -----------------------------------------
# Settings
# -----------------------------------------

$database = "AdventureWorks2019"
$server = "localhost"
$prefix = "SqlSizer."


$login = "someuser"
$password = "pass"
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

$cred = new-object System.Management.Automation.PSCredential -argumentlist $login,$securePassword

$red = 1 # find all data that is referenced by the row (recursively)
$green = 2 # find all data that is dependent on the row
$yellow = 3 # find all related data to the row (subset)

#-----------------------------------------

Init

#------------------------------
# Data definition
#------------------------------
$query = "SELECT  TOP 1 'Person' as SchemaName, 'Person' as TableName, [BusinessEntityID] as Key1, NULL as Key2, NULL as Key3, NULL as Key4, " + $yellow +  " as Color, 0,0,NULL,1 FROM Person.Person where FirstName = 'Mary'"

$tmp = "INSERT INTO SqlSizer.Processing " + $query
$_ = ExecuteSQL -Sql $tmp -Database $database


# ==============
# Execution
# ==============

# Find related
$time = Measure-Command {
    $result = FindRelated
}



# Create new db
CopyDatabase
Truncate # clear db and disable reference checks

# Copy data
CopyData -source $database -destination ($prefix + $database) -related $result

# Enable referece checks
EnableChecks


#end of script
Write-Host
Write-Host
Write-Host "=========================================="
Write-Host "Subsetting time: " + $time
Write-Host "=========================================="
if ($result -is [array])
{
    Write-Host "Total count of records: " $result.Count
}
else
{
    Write-Host "Total count of records: 1"
}
Write-Host "=========================================="

$groups = $result | Group-Object -Property Schema, TableName
foreach ($group in $groups)
{
    Write-Host ($group.Name + " " + $group.Count)
}
Write-Host "=========================================="

Write-Host