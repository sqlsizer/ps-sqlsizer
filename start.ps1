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
        if (($row["TABLE_NAME"] -eq $tableName) -and ($row["TABLE_SCHEMA"] -eq $schema) -and ($row["COLUMN_NAME"] -eq $columnName))
        {
            $row["DATA_TYPE"]
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
        "CONVERT(varchar, " + $columnName + ")"
    }
    else
    {
        $columnName
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


function CopyData
{
    param (
        [string]$server,
        [string]$source,
        [string]$destination,
        [Object]$related
    )

    $groups = $result | Group-Object -Property Schema, TableName


    foreach ($group in $groups)
    {
        foreach ($item in $group.Group)
        {
            #TODO
            #$sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON INSERT INTO " +  $schema + ".[" +  $tableName + "] SELECT * FROM " + $source + "." + $schema + ".[" +  $tableName + "] SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF"
            #Invoke-Sqlcmd -Query $sql -ServerInstance $server -Database $destination
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

#end of script