# -----------------------------------------

function Init
{
    param
    (
        [string]$database,
        [string]$server
    )

    $tmp = "IF OBJECT_ID('SqlSizer.PKValues') IS NOT NULL  
        Drop Table SqlSizer.PKValues"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "IF OBJECT_ID('SqlSizer.Processing') IS NOT NULL
        Drop Table SqlSizer.Processing"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "DROP SCHEMA IF EXISTS SqlSizer"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "CREATE SCHEMA SqlSizer"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "CREATE TABLE SqlSizer.PKValues (Id int primary key identity(1,1), Key1 varchar(32), Key2 varchar(32), Key3 varchar(32), Key4 varchar(32))"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "CREATE TABLE SqlSizer.Processing (Id int primary key identity(1,1), [Schema] varchar(64), TableName varchar(64), Key1 varchar(32), Key2 varchar(32), Key3 varchar(32), Key4 varchar(32), [type] int, [status] int)"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "CREATE UNIQUE INDEX [Index] ON SqlSizer.[PKValues] ([Key1] ASC, [Key2] ASC, [Key3] ASC, [Key4] ASC)"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "CREATE UNIQUE INDEX [Index] ON SqlSizer.[Processing] ([Schema] ASC, TableName ASC, [Key1] ASC, [Key2] ASC, [Key3] ASC, [Key4] ASC, [type] ASC)"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
    
    $tmp = "TRUNCATE TABLE SqlSizer.Processing"
    Invoke-Sqlcmd -Query $tmp -ServerInstance $server -Database $database
}

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

function GetColumnValue
{
    param 
    (
        [string]$schema,
        [string]$tableName,
        [string]$columnName,
        [System.Data.DataRow[]]$rows
    )

    $type = GetType -schema $schema -tableName $tableName -columnName $columnName -rows $rows

    if ($type -eq "hierarchyid")
    {
        "CONVERT(varchar(max), " + $columnName + ")"
    }
    else 
    {
        if ($type -eq "xml")
        {
            "CONVERT(varchar(max), " + $columnName + ")"
        }
        else
        {
            $columnName
        }
    }
}


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

    if (($type -eq "varchar") -or ($type -eq "nvarchar") -or ($type -eq "datetime") -or ($type -eq "nchar") -or ($type -eq "char"))
    {
        "'" + $value + "'"
    }
    else
    {
        $value
    }
}

function FindRelated
{
    param 
    (
        [string]$database,
        [string]$server
    )

    $primaryKeysSql = Get-Content -Path "PrimaryKeys.sql" -Raw
    $foreignKeysSql = Get-Content -Path "ForeignKeys.sql" -Raw
    
    $primaryKeys = Invoke-Sqlcmd -Query $primaryKeysSql -ServerInstance $server -Database $database
    $foreignKeys = Invoke-Sqlcmd -Query $foreignKeysSql -ServerInstance $server -Database $database
    
    $columnsSql = Get-Content -Path "Columns.sql" -Raw
    $columns = Invoke-Sqlcmd -Query $columnsSql -ServerInstance $server -Database $database

    $processed = @{ }
    $result = @()
    
    while ($true)
    { 
        $q = "SELECT TOP 1 [Schema], TableName, Type  FROM SqlSizer.Processing WHERE Status = 0"
        $first = Invoke-Sqlcmd -Query $q -ServerInstance $server -Database $database
    
        if ($first -eq $null)
        {
            break
        }
    
        $q = "TRUNCATE TABLE SqlSizer.PKValues "
        Invoke-Sqlcmd -Query $q -ServerInstance $server -Database $database
    
    
        $q = "INSERT INTO SqlSizer.PKValues " +  "SELECT Key1, Key2, Key3, Key4 FROM SqlSizer.Processing WHERE Status = 0 AND Type = " + $first.Type + " AND TableName = '" + $first.TableName + "' and [Schema] = '" + $first.Schema + "'"
        Invoke-Sqlcmd -Query $q -ServerInstance $server -Database $database
    
        $primaryKey = GetPrimaryKey -Schema $first.Schema -TableName $first.TableName -PrimaryKeys $primaryKeys
        $foreignKeysForTable = GetForeignKeys -Schema $first.Schema -TableName $first.TableName -ForeignKeys $foreignKeys
        $referenced = GetReferencedKeys -Schema $first.Schema -TableName $first.TableName -ForeignKeys $foreignKeys
    
       
        if ($first.Type -eq 2) 
        {
           foreach ($fRow in $foreignKeysForTable)
           {
               $fkTableSchema = $fRow["schema_name"]
               $fkTable = $fRow["table"]
               $fkColumn = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $fRow["column"] -rows $columns

               if ($primaryKey.Count -eq 1)
               {
                   $primaryKey = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey -rows $columns
                   $sql = "SELECT DISTINCT " +  $fkColumn + " as val FROM " + $fkTableSchema + "." + $fkTable + " INNER JOIN SqlSizer.PkValues p ON " + $primaryKey + " = p.Key1"
               }
           
            
               if ($primaryKey.Count -eq 2)
               {
                   $primaryKey[0] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[0] -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[1] -rows $columns
                   $sql = "SELECT DISTINCT " +  $fkColumn + " as val FROM " + $fkTableSchema + "." + $fkTable + " INNER JOIN SqlSizer.PkValues p ON " + $primaryKey[0] + " = p.Key1 and " + $primaryKey[1] + " = p.Key2"
               }

               if ($primaryKey.Count -eq 3)
               {
                   $primaryKey[0] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[0] -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[1] -rows $columns
                   $primaryKey[2] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[2] -rows $columns
                   $sql = "SELECT DISTINCT " +  $fkColumn + " as val FROM " + $fkTableSchema + "." + $fkTable + " INNER JOIN SqlSizer.PkValues p ON " + $primaryKey[0] + " = p.Key1 and " + $primaryKey[1] + " = p.Key2 and " + $primaryKey[2] + " = p.Key3"
               }
               
               if ($primaryKey.Count -eq 4)
               {
                   $primaryKey[0] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[0] -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[1] -rows $columns
                   $primaryKey[2] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[2] -rows $columns
                   $primaryKey[3] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[3] -rows $columns
                   $sql = "SELECT DISTINCT " +  $fkColumn + " as val FROM " + $fkTableSchema + "." + $fkTable + " INNER JOIN SqlSizer.PkValues p ON " + $primaryKey[0] + " = p.Key1 and " + $primaryKey[1] + " = p.Key2 and " + $primaryKey[2] + "= p.Key3 and " + $primaryKey[3] + " = p.Key4"
               }
    
               $sql = $sql + " AND NOT EXISTS(SELECT * FROM SqlSizer.Processing WHERE [Schema] = '" + $fRow["schema2_name"] + "' and TableName = '" + $fRow["referenced_table"] + "' and  Key1 = " + $fRow["column"] + ")"
               $insert = "INSERT INTO SqlSizer.Processing SELECT '" +$fRow["schema2_name"] + "', '"  +  $fRow["referenced_table"] + "', x.val, NULL, NULL, NULL, 2, 0 FROM (" + $sql + ") x"
               
               $_ = Invoke-Sqlcmd  -Query $insert -ServerInstance $server -Database $database

               $insert = "INSERT INTO SqlSizer.Processing SELECT '" +$fRow["schema2_name"] + "', '"  +  $fRow["referenced_table"] + "', x.val, NULL, NULL, NULL, 1, 0 FROM (" + $sql + ") x"
               $_ = Invoke-Sqlcmd  -Query $insert -ServerInstance $server -Database $database
              
           }
        }
    
        if ($first.Type -eq 1)
        {
    
           foreach ($fRow in $referenced)
           {
               $fkTableSchema = $fRow["schema_name"]
               $fkTable = $fRow["table"]
               $primaryKey = GetPrimaryKey -Schema $fkTableSchema -TableName $fkTable -PrimaryKeys $primaryKeys
               $fkColumn = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $fRow["column"] -rows $columns

               if ($primaryKey.Count -eq 1)
               {
                    $primaryKey = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey -rows $columns
                    $sql = "SELECT DISTINCT " +  $primaryKey + " as val FROM " + $fkTableSchema + "." + $fkTable + " WHERE " + $fkColumn + " IN (SELECT Key1 FROM SqlSizer.PkValues)"    
               }
               
               if ($primaryKey.Count -eq 2)
               {
                   $primaryKey[0] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[0] -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[1] -rows $columns

                   $sql = "SELECT DISTINCT " +  $primaryKey[0] + " as val, " +  $primaryKey[1] + " as val2  FROM " + $fkTableSchema + "." + $fkTable + " WHERE " + $fkColumn + " IN (SELECT Key1 FROM SqlSizer.PkValues)"  
               }

               if ($primaryKey.Count -eq 3)
               {
                   $primaryKey[0] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[0] -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[1] -rows $columns
                   $primaryKey[2] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[2] -rows $columns

                   $sql = "SELECT DISTINCT " +  $primaryKey[0] + " as val, " +  $primaryKey[1] + " as val2, " +   $primaryKey[2] + " as val3 FROM " + $fkTableSchema + "." + $fkTable + " WHERE " + $fkColumn  + " IN (SELECT Key1 FROM SqlSizer.PkValues)"   
               }
               
               if ($primaryKey.Count -eq 4)
               {
                   $primaryKey[0] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[0] -rows $columns
                   $primaryKey[1] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[1] -rows $columns
                   $primaryKey[2] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[2] -rows $columns
                   $primaryKey[3] = GetColumnValue -schema $fkTableSchema -tableName $fkTable -columnName $primaryKey[3] -rows $columns

                   $sql = "SELECT DISTINCT " +  $primaryKey[0] + " as val, " +  $primaryKey[1] + " as val2, " +   $primaryKey[2] + " as val3, " +  $primaryKey[3] + " as val4  FROM " + $fkTableSchema + "." + $fkTable + " WHERE " + $fkColumn  + " IN (SELECT Key1 FROM SqlSizer.PkValues)"   
               }

               $sql = $sql + " AND NOT EXISTS(SELECT * FROM SqlSizer.Processing WHERE [Type] = 3 and [Schema] = '" + $fkTableSchema + "' and TableName = '" + $fkTable + "' and  Key1 = " + $fkColumn + ")"
               $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $fkTableSchema + "', '"  +  $fkTable + "'"
               
               if ($primaryKey.Count -eq 1)
               {
                   $insert = $insert + ", x.val, NULL, NULL, NULL, 3, 0 FROM (" + $sql + ") x"
               }

               if ($primaryKey.Count -eq 2)
               {
                   $insert = $insert + ", x.val, x.val2, NULL, NULL, 3, 0 FROM (" + $sql + ") x"
               }


               if ($primaryKey.Count -eq 3)
               {
                   $insert = $insert + ", x.val, x.val2, x.val3, NULL, 3, 0 FROM (" + $sql + ") x"
               }

               if ($primaryKey.Count -eq 4)
               {
                   $insert = $insert + ", x.val, x.val2, x.val3, x.val4, 3, 0 FROM (" + $sql + ") x"
               }

               $_ = Invoke-Sqlcmd  -Query $insert -ServerInstance $server -Database $database
           }
        }
    
        if ($first.Type -eq 3)
        {
            $q = "INSERT INTO SqlSizer.Processing " +  "SELECT [Schema], TableName, Key1, Key2, Key3, Key4, 1, 0 FROM SqlSizer.Processing WHERE Status = 0 AND Type = " + $first.Type + " AND TableName = '" + $first.TableName + "'"  +  " UNION " +  "SELECT [Schema], TableName, Key1, Key2, Key3, Key4, 2, 0 FROM SqlSizer.Processing WHERE Status = 0 AND Type = " + $first.Type + " AND TableName = '" + $first.TableName + "'"
            $_ = Invoke-Sqlcmd -Query $q -ServerInstance $server -Database $database
        }
         
        $q = "UPDATE SqlSizer.Processing SET Status = 1 WHERE [Schema] = '" + $first.Schema + "' and TableName = '" + $first.TableName + "' and Type = " + $first.Type + " and Status = 0"
        Invoke-Sqlcmd -Query $q -ServerInstance $server -Database $database
    
    }
    
    $q = "SELECT DISTINCT [Schema], TableName, Key1, Key2, Key3, Key4 FROM SqlSizer.Processing"
    Invoke-Sqlcmd -Query $q -ServerInstance $server -Database $database
}

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
              $select += $row["column"]
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

function GetTableWhere
{
     param (
        [string]$Schema,
        [string]$TableName,
        [System.Data.DataRow[]]$PrimaryKeys,
        [string]$Key1,
        [string]$Key2,
        [string]$Key3,
        [string]$Key4
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
         " WHERE " + $primaryKey + " = " + $Key1
     }
     
     if ($primaryKey.Count -eq 2)
     {
        " WHERE " + $primaryKey[0] + " = " + $Key1 + " and " + $primaryKey[1] + " = " + $Key2
     }

     if ($primaryKey.Count -eq 3)
     {
        " WHERE " + $primaryKey[0] + " = " + $Key1 + " and " + $primaryKey[1] + " = " + $Key2 + " and " + $primaryKey[2] + " = " + $Key3
     }
}


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

function AddToProcessing
{
    param (
        [string]$server,
        [string]$database,
        [string]$schema,
        [string]$table,
        [string]$key,
        [string]$key2 = 'NULL',
        [string]$key3 = 'NULL',
        [string]$key4 = 'NULL',
        [int]$type
    )

    $q = "INSERT INTO SqlSizer.Processing VALUES('" + $schema + "','" + $table + "'," + (QuoteIfNeeded -Val $key) + "," + (QuoteIfNeeded -Val $key2)  + "," +(QuoteIfNeeded -Val $key3) + "," +(QuoteIfNeeded -Val $key4) + "," + $type + ", 0)"
    Invoke-Sqlcmd -Query $q -ServerInstance $server -Database $database
}


function CopyDatabase
{
     param (
        [string]$server,
        [string]$source,
        [string]$prefix,
        [string]$login
    )

   
    Copy-DbaDatabase  -Source $server -Destination $server -Database $source  -Prefix $prefix -BackupRestore -SharedPath (Get-DbaDefaultPath -SqlInstance $server).Backup
    Copy-DbaLogin -Source $server -Destination $server -Login AppReadOnly, AppReadWrite, $login

}


function Truncate
{
     param (
        [string]$server,
        [string]$database
    )

    $sql = Get-Content -Raw -Path "Tables.sql"
    $tables = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database

    $sql = "sp_msforeachtable 'ALTER TABLE ? DISABLE TRIGGER all'"
    $_ = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database

    foreach ($table in $tables)
    {
        $sql = "ALTER TABLE " + $table["schema"] + "." + $table["table"] + " NOCHECK CONSTRAINT ALL"
        $_ = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database
    }

    foreach ($table in $tables)
    {
        $sql = "DELETE FROM " + $table["schema"] + "." + $table["table"]        
        $_ = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database
    }
}

function EnableChecks
{
    param (
        [string]$server,
        [string]$database
    )

    $sql = Get-Content -Raw -Path "Tables.sql"
    $tables = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database

    $sql = "sp_msforeachtable 'ALTER TABLE ? ENABLE TRIGGER all'"
    $_ = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database

    $sql = "DBCC SHRINKDATABASE ([" + $database + "])"
    Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database
}


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


function GetTablesWithIdentityInsert
{
     param (
        [string]$server,
        [string]$database
    )

    $sql = Get-Content -Raw -Path "Identity.sql"
    $tables = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database
    
    $tables
}

function SetIdentityInsertOn
{
     param (
        [string]$server,
        [string]$database
    )

    $sql = Get-Content -Raw -Path "Identity.sql"
    $tables = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database

    foreach ($table in $tables)
    {
        $sql = "SET IDENTITY_INSERT " + $table["schema"] + "." + $table["table"] + " ON"
        $_ = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database
    }
}

function SetIdentityInsertOff
{
     param (
        [string]$server,
        [string]$database
    )

    $sql = Get-Content -Raw -Path "Identity.sql"
    $tables = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database

    foreach ($table in $tables)
    {
        $sql = "SET IDENTITY_INSERT " + $table["schema"] + "." + $table["table"] + " OFF"
        $_ = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $database
    }
}


function CopyData
{
    param (
        [string]$server,
        [string]$source,
        [string]$destination,
        [Object]$related
    )
    
    $columnsSql = Get-Content -Path "Columns.sql" -Raw
    $columns = Invoke-Sqlcmd -Query $columnsSql -ServerInstance $server -Database $database
    
    $identityTables = GetTablesWithIdentityInsert -server $server -database $source
    
    $computedSql = Get-Content -Path "Computed.sql" -Raw
    $computed =  Invoke-Sqlcmd -Query $computedSql -ServerInstance $server -Database $database

    $primaryKeysSql = Get-Content -Path "PrimaryKeys.sql" -Raw
    $primaryKeys = Invoke-Sqlcmd -Query $primaryKeysSql -ServerInstance $server -Database $database

    $groups = $result | Group-Object -Property Schema, TableName
    foreach ($group in $groups)
    {
        foreach ($item in $group.Group)
        {
            $tableName = $item.TableName
            $schema = $item.Schema
            $tableColumns = GetTableSelect -Columns $columns -TableName $tableName -Schema $schema -Computed $computed -Raw $true
            $tableSelect = GetTableSelect -Columns $columns -TableName $tableName -Schema $schema -Computed $computed -Raw $false

            $where = GetTableWhere -Columns $columns -TableName $tableName -Schema $schema -PrimaryKeys $primaryKeys -Key1 $item.Key1 -Key2 $item.Key2 -Key3 $item.Key3 -Key4 $item.Key4

            $isIdentity = HasIdentity -Schema $schema -TableName $tableName -Identifies $identityTables

            $sql = "INSERT INTO " +  $schema + ".[" +  $tableName + "] (" + $tableColumns + ") SELECT " + $tableSelect +  " FROM " + $source + "." + $schema + ".[" +  $tableName + "]"
        
            $sql = $sql + $where

            if ($isIdentity)
            {
                $sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON " + $sql + " SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF" 
            }
            $_ = Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $destination
        }
    }
}


# -----------------------------------------



# Settings

$database = "AdventureWorks"
$server = "localhost"
$prefix = "SqlSizer2."
$login = ''


# Init
Init -server $server -database $database

# Add desired data
AddToProcessing -server $server -database $database -schema "Person" -table "Person" -key "2" -type 3

# Find related
Measure-Command {
    $result = FindRelated -server $server -database $database
}

# Create new db
CopyDatabase -server $server -source $database -prefix $prefix -login $login
Truncate -server $server -database ($prefix + $database)

# Copy data
CopyData -server $server -source $database -destination ($prefix + $database) -related $result

# Enable referece checks
EnableChecks -server $server -database ($prefix + $database)

#end of scriptc