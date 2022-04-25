function Get-Subset
{
    
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string[]]$Queries,

        [Parameter(Mandatory=$true)]
        [bool]$ReturnData,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $processed = @{ }
    $result = @()
    
    $red = 1 # find all data that is referenced by the row (recursively)
    $green = 2 # find all data that is dependent on the row
    $yellow = 3 # find all related data to the row (subset)
    

    $info = Get-TablesInfo -Database $Database -ConnectionInfo $ConnectionInfo

    $_ = Init-Structures -Database $Database -ConnectionInfo $ConnectionInfo -DatabaseInfo $info
    

    foreach ($query in $queries)
    {
        $tmp = "INSERT INTO SqlSizer.Processing " + $query
        $_ = Execute-SQL -Sql $tmp -Database $database -ConnectionInfo $ConnectionInfo
    }
    $_ = Init-Statistics -Database $Database -ConnectionInfo $ConnectionInfo
    
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

        $q = "INSERT INTO SqlSizer.Slice " +  "SELECT DISTINCT " + $keys + " Depth, Id FROM SqlSizer.Processing WHERE Status = 0 AND Type = " + $color + " AND TableName = '" + $tableName + "' and [Schema] = '" + $schema + "'"
        $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    
        $cond = ""
        for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i++)
        {
            if ($i -gt 0)
            {
                $cond += " and "
            }

            $cond = $cond + "(p.Key" + $i + " = s.Key" + $i + " OR s.Key" + $i + " IS NULL)"
        }
            
        # Red color - 1
        if ($color -eq $red) 
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
                        $join = " and "
                    }
                    $columns = $columns + " f." + $fkColumn.Name + " = p.Key" + $i
                    $i += 1
               }
               $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.parent = s.ProcessingId and p.[Schema] = '" + $fk.Schema + "' and p.TableName = '" + $fk.Table + "' and " + $columns +  ")"


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
                    $columns = $columns + " f." + $fkColumn.Name + " as val" + $i + ","
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

               $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $fk.Schema + "', '" + $fk.Table + "', " + $columns + " 1, 0, x.Depth + 1, x.ProcessingId, 0 FROM (" + $sql + ") x"
              
               $insert = $insert + " SELECT @@ROWCOUNT AS Count"
               $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo

               $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.Schema + "' and [TableName] = '" +  $fk.Table + "'"
               $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
            }
        }

        # Green Color - 2
        if ($color -eq $green)
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
                foreach ($fkColumn in $fk.FkColumns)
                { 
                     if ($i -gt 0)
                     {
                         $join += " and "
                     }
                     $columns = $columns + " f." + $fkColumn.Name + " = p.Key" + $i
                     $i += 1
                }
                $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.parent = s.ProcessingId and p.[Schema] = '" + $fk.Schema + "' and p.TableName = '" + $fk.Table + "' and " + $columns +  ")"
                
                
                # from
                $join = " INNER JOIN SqlSizer.Slice s ON "
                $i = 0    

                foreach ($fkColumn in $fk.FkColumns)
                {
                    if ($i -gt 0)
                    {
                         $join = " and "
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
                     $columns = $columns + " f." + $primaryKeyColumn.Name + " as val" + $i + ","
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
                
                $insert = "INSERT INTO SqlSizer.Processing SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns + " 1, 0, x.Depth + 1, x.ProcessingId, 0 FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"
                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                
                $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.FkSchema + "' and [TableName] = '" +   $fk.FkTable + "'"
                $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
             }
           }
        }
        
        # Yellow - 3 -> Split into Red and Green
        if ($first.Type -eq $yellow)
        {
            $columns = ""
            for ($i = 0; $i -lt $info.PrimaryKeyMaxSize; $i++)
            {
                $columns = $columns + "s.Key" + $i + ","
            }
            
            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 1 and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO SqlSizer.Processing " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " 1, 0, s.Depth, s.ProcessingId, 0 FROM SqlSizer.Slice s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "'"
            $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM SqlSizer.Processing p WHERE p.[Type] = 2 and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO SqlSizer.Processing " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " 2, 0, s.Depth, s.ProcessingId, 0 FROM SqlSizer.Slice s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "'"
            $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
        }
        
        # Update status
        $q = "UPDATE p SET Status = 1 FROM SqlSizer.Processing p WHERE [Schema] = '" + $schema + "' and TableName = '" + $tableName + "' and [Type] = " + $color + " and Status = 0 and EXISTS(SELECT * FROM SqlSizer.Slice s WHERE " + $cond + ") SELECT @@ROWCOUNT AS Count"
        $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

        # update stats
        $q = "UPDATE SqlSizer.ProcessingStats SET Processed = Processed + " + $results.Count + ", ToProcess = ToProcess - " + $results.Count +  " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "'"
        $_ = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    }
    
    if ($ReturnData)
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

