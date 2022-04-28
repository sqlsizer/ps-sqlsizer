function Get-Subset
{
    
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [bool]$Return,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $processed = @{ }
    $result = @()
  
    $_ = Init-Statistics -Database $Database -ConnectionInfo $ConnectionInfo
    $info = Get-DatabaseInfo -Database $Database -ConnectionInfo $ConnectionInfo

    $keys = ""
    for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i++)
    {
       $keys = $keys + "Key" + $i + ","
    }
    
    while ($true)
    { 
        $q = "SELECT TOP 1 p.[Schema], p.TableName, Type  FROM SqlSizer.Processing p JOIN SqlSizer.ProcessingStats ps ON p.[Schema] = ps.[Schema] and p.[TableName] = ps.[TableName] WHERE Status = 0 ORDER BY ToProcess DESC"
        $first = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    
        if ($first -eq $null)
        {
            break
        }

        $schema = $first.Schema
        $tableName = $first.TableName
        $color = $first.Type

        $table = $info.Tables | Where-Object {($_.SchemaName -eq $schema) -and ($_.TableName -eq $tableName)}
    
        $q = "TRUNCATE TABLE SqlSizer.Slice"
        $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

        $q = "INSERT INTO SqlSizer.Slice " +  "SELECT DISTINCT " + $keys + " Depth FROM SqlSizer.Processing WHERE Status = 0 AND Type = " + $color + " AND TableName = '" + $tableName + "' and [Schema] = '" + $schema + "'"
        $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    
        $cond = ""
        for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
        {
            if ($i -gt 0)
            {
                $cond += " and "
            }

            $cond = $cond + "(p.Key" + $i + " = s.Key" + $i + ")"
        }
            
        # Red color
        if ($color -eq [int][Color]::Red) 
        {
           foreach ($fk in $table.ForeignKeys)
           {
               $primaryKey = $table.PrimaryKey

               #where
               $columns = ""
               $i = 0
               foreach ($fkColumn in $fk.FkColumns)
               { 
                    if ($i -gt 0)
                    {
                        $columns += " and "
                    }
                    $columns = $columns + " f." + $fkColumn.Name + " = p.Key" + $i
                    $i += 1
               }
               $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = " + [int][Color]::Red + " and p.[Schema] = '" + $fk.Schema + "' and p.TableName = '" + $fk.Table + "' and " + $columns +  ")"


               # from
               $join = " INNER JOIN SqlSizer.Slice s ON "
               $i = 0             
               foreach ($primaryKeyColumn in $primaryKey)
               {
                    if ($i -gt 0)
                    {
                        $join += " and "
                    }

                    $join += " s.Key" + $i + " = f." + $primaryKeyColumn.Name
                    $i += 1
               }
               $from = " FROM " + $schema + "." + $tableName  + " f " + $join

               # select
               $columns = ""
               $i = 0
               foreach ($fkColumn in $fk.FkColumns)
               {
                    $columns = $columns + (GetColumnValue -columnName $fkColumn.Name -prefix "f." -dataType $fkColumn.dataType) + " as val" + $i + ","
                    $i += 1
               }

               if ($i -lt $info.PrimaryKeyMaxSize)
               {
                    for ($i; $i -lt $info.PrimaryKeyMaxSize; $i = $i + 1)
                    {
                        $columns = $columns + " NULL as val" + $i + ", "
                    }
               }

               $select = "SELECT " + $columns + " s.Depth as Depth, s.ProcessingId as ProcessingId "
               $sql = $select + $from + $where


               $columns = ""
               for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i = $i + 1)
               {
                    $columns = $columns + "x.val" + $i + ","
               }

               $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $fk.Schema + "', '" + $fk.Table + "', " + $columns + " " + [int][Color]::Red + ", 0, x.Depth + 1, 0 FROM (" + $sql + ") x"
              
               $insert = $insert + " SELECT @@ROWCOUNT AS Count"
               $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo

               $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.Schema + "' and [TableName] = '" +  $fk.Table + "'"
               $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
            }
        }

        # Green Color
        if ($color -eq [int][Color]::Green) 
        {
           foreach ($referencedByTable in $table.IsReferencedBy)
           {
             $fks = $referencedByTable.ForeignKeys | Where-Object {($_.Schema -eq $schema) -and ($_.Table -eq $tableName)}
             foreach ($fk in $fks)
             {
                $primaryKey = $referencedByTable.PrimaryKey

                #where
                $columns = ""
                $i = 0
                foreach ($pk in $primaryKey)
                { 
                     if ($i -gt 0)
                     {
                         $columns += " and "
                     }
                     $columns = $columns + " f." + $pk.Name + " = p.Key" + $i
                     $i += 1
                }
                $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = " + [int][Color]::Yellow +  " and p.[Schema] = '" + $fk.FkSchema + "' and p.TableName = '" + $fk.FkTable + "' and " + $columns +  ")"
                
                
                # from
                $join = " INNER JOIN SqlSizer.Slice s ON "
                $i = 0    

                foreach ($fkColumn in $fk.FkColumns)
                {
                    if ($i -gt 0)
                    {
                         $join += " and "
                    }
                
                    $join += " s.Key" + $i + " = f." + $fkColumn.Name
                    $i += 1
                }
         
                $from = " FROM " + $referencedByTable.SchemaName + "." + $referencedByTable.TableName   + " f " + $join
                
                # select
                $columns = ""
                $i = 0
                foreach ($primaryKeyColumn in $primaryKey)
                {
                    $columns = $columns + (GetColumnValue -columnName $primaryKeyColumn.Name -prefix "f." -dataType $primaryKeyColumn.dataType) + " as val" + $i + ","
                    $i += 1
                }
                
                if ($i -lt $info.PrimaryKeyMaxSize)
                {
                     for ($i; $i -lt $info.PrimaryKeyMaxSize; $i = $i + 1)
                     {
                         $columns = $columns + " NULL as val" + $i + ", "
                     }
                }
                
                $select = "SELECT " + $columns + " s.Depth as Depth, s.ProcessingId as ProcessingId "
                $sql = $select + $from + $where
                
                
                $columns = ""
                for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i = $i + 1)
                {
                     $columns = $columns + "x.val" + $i + ","
                }
                
                $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns  + " " + [int][Color]::Yellow +  ", 0, x.Depth + 1, 0 FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"
                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                
                $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.FkSchema + "' and [TableName] = '" +   $fk.FkTable + "'"
                $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
             }
           }
        }
        
        # Yellow -> Split into Red and Green
        if ($color -eq [int][Color]::Yellow) 
        {
            $columns = ""
            for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i++)
            {
                $columns = $columns + "s.Key" + $i + ","
            }
            
            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = " + [int][Color]::Red  + "  and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO SqlSizer.Processing " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Red + ", 0, s.Depth, 0 FROM SqlSizer.Slice s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "'"
            $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = " + [int][Color]::Green  + " and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO SqlSizer.Processing " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Green + ", 0, s.Depth, 0 FROM SqlSizer.Slice s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "'"
            $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
        }

        # Blue Color
        if ($color -eq [int][Color]::Blue) 
        {
           foreach ($referencedByTable in $table.IsReferencedBy)
           {
             $fks = $referencedByTable.ForeignKeys | Where-Object {($_.Schema -eq $schema) -and ($_.Table -eq $tableName)}
             foreach ($fk in $fks)
             {
                $primaryKey = $referencedByTable.PrimaryKey

                #where
                $columns = ""
                $i = 0
                foreach ($pk in $primaryKey)
                { 
                     if ($i -gt 0)
                     {
                         $columns += " and "
                     }
                     $columns = $columns + " f." + $pk.Name + " = p.Key" + $i
                     $i += 1
                }
                $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = " + [int][Color]::Blue +  " and p.[Schema] = '" + $fk.FkSchema + "' and p.TableName = '" + $fk.FkTable + "' and " + $columns +  ")"
                
                
                # from
                $join = " INNER JOIN SqlSizer.Slice s ON "
                $i = 0    

                foreach ($fkColumn in $fk.FkColumns)
                {
                    if ($i -gt 0)
                    {
                         $join += " and "
                    }
                
                    $join += " s.Key" + $i + " = f." + $fkColumn.Name
                    $i += 1
                }
         
                $from = " FROM " + $fk.FkSchema + "." + $fk.FkTable   + " f " + $join
                
                # select
                $columns = ""
                $i = 0
                foreach ($primaryKeyColumn in $primaryKey)
                {
                    $columns = $columns + (GetColumnValue -columnName $primaryKeyColumn.Name -prefix "f." -dataType $primaryKeyColumn.dataType) + " as val" + $i + ","
                    $i += 1
                }
                
                if ($i -lt $info.PrimaryKeyMaxSize)
                {
                     for ($i; $i -lt $info.PrimaryKeyMaxSize; $i = $i + 1)
                     {
                         $columns = $columns + " NULL as val" + $i + ", "
                     }
                }
                
                $select = "SELECT " + $columns + " s.Depth as Depth "
                $sql = $select + $from + $where
                
                
                $columns = ""
                for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i = $i + 1)
                {
                     $columns = $columns + "x.val" + $i + ","
                }
                
                $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns  + " " + [int][Color]::Blue +  ", 0, x.Depth + 1, 0 FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"
                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                
                $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.FkSchema + "' and [TableName] = '" +   $fk.FkTable + "'"
                $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
             }
           }
        }
        
        # Update status
        $q = "UPDATE p SET Status = 1 FROM SqlSizer.Processing p WHERE [Schema] = '" + $schema + "' and TableName = '" + $tableName + "' and [Type] = " + $color + " and Status = 0 and EXISTS(SELECT 1 FROM SqlSizer.Slice s WHERE " + $cond + ") SELECT @@ROWCOUNT AS Count"
        $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo 

        # update stats
        $q = "UPDATE SqlSizer.ProcessingStats SET Processed = Processed + " + $results.Count + ", ToProcess = ToProcess - " + $results.Count +  " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "'"
        $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    }
    
   
    if ($Return)
    {
        $columns = ""
        for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i++)
        {
            $columns = $columns + "Key" + $i
    
            if ($i -lt ($info.PrimaryKeyMaxSize - 1))
            {
                $columns += ","
            }
        }
        $q = "SELECT DISTINCT [Schema], TableName, " + $columns + "  FROM SqlSizer.Processing"
        Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
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
        if ($dataType -eq "xml")
        {
            "CONVERT(nvarchar(max), " + $prefix + $columnName + ")"
        }
        else
        {
            "[" + $columnName + "]"
        }
    }
}
