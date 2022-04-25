function Copy-Data
{
    
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-TablesInfo -Database $Source -Connection  $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        $isIdentity = $table.IsIdentity
        $schema = $table.SchemaName
        $tableName = $table.TableName
        
        $tableColumns = GetTableSelect -TableInfo $table -Raw $true
        $tableSelect = GetTableSelect -TableInfo $table -Raw $true
        $where = GetTableWhere -Database $Source -TableInfo $table

        $sql = "INSERT INTO " +  $schema + ".[" +  $tableName + "] (" + $tableColumns + ") SELECT " + $tableSelect +  " FROM " + $Source + "." + $schema + ".[" +  $tableName + "]"
        
        $sql = $sql + $where
        if ($isIdentity)
        {
            $sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON " + $sql + " SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF" 
        }
        $_ = Execute-SQL -Sql $sql -Database $Destination -ConnectionInfo $ConnectionInfo 
    }
   
}

function GetTableSelect
{
    param (
        [bool]$Raw,
        [TableInfo]$TableInfo
    )

    
    for ($i = 0; $i -lt $table.Columns.Count; $i++)
    {
        $column = $table.Columns[$i]

        $columnName = $column.Name
        $isComputed = $column.IsComputed

        if ($isComputed -eq $true)
        {
            continue
        }
        else
        {
        
            if ($i -gt 0)
            {
                $select += ","
            }

            if ($Raw)
            {
                $select +=  "[" + $columnName + "]"
            }
            else
            {
                $select += GetColumnValue -columnName $columnName -dataType $table.ColumnsTypes[$i]
            }
        }
    }

    $select
}

# Function that creates a where part of query
function GetTableWhere
{
     param (
        [string]$Database,
        [TableInfo]$TableInfo
     )

     $primaryKey = $TableInfo.PrimaryKeys
     
     
     if ($primaryKey.Count -eq 1)
     {
         " WHERE EXISTS(SELECT * FROM " + $Database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey.Name  + ")"
     }
     
     if ($primaryKey.Count -eq 2)
     {
        " WHERE EXISTS(SELECT * FROM " + $Database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey[0].Name + " AND Key2 = " + $primaryKey[1].Name + ")"
     }

     if ($primaryKey.Count -eq 3)
     {
        " WHERE EXISTS(SELECT * FROM " + $Database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey[0].Name + " AND Key2 = " + $primaryKey[1].Name + " AND Key3 = " + $primaryKey[2].Name + ")"
     }

     if ($primaryKey.Count -eq 4)
     {
        " WHERE EXISTS(SELECT * FROM " + $Database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' " + "AND Key1 = " + $primaryKey[0].Name + " AND Key2 = " + $primaryKey[1].Name + " AND Key3 = " + $primaryKey[2].Name + " AND Key4 = " + $primaryKey[3].Name + ")"
     }
}

function GetColumnValue
{
    param 
    (
        [string]$columnName,
        [string]$dataType,
        [string]$prefix
    )

    if ($dataType -eq "hierarchyid")
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
