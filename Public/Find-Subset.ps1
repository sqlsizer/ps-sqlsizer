function Find-Subset
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$false)]
        [ColorMap]$ColorMap = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $start = Get-Date
    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $null = Initialize-Statistics -Database $Database -ConnectionInfo $ConnectionInfo -DatabaseInfo $info
    
    $structure = [Structure]::new($info)

    # Test ignored tables
    Test-IgnoredTables -Database $Database -ConnectionInfo $ConnectionInfo -IgnoredTables $IgnoredTables

    $interval = 5
    $tablesGrouped = $info.Tables | Group-Object -Property SchemaName, TableName -AsHashTable -AsString

    while ($true)
    { 
        # Progress handling
        $totalSeconds = (New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds
        if ($totalSeconds -gt ($lastTotalSeconds + $interval))
        {
            $lastTotalSeconds = $totalSeconds
            $progress = Get-SubsetProgress -Database $Database -ConnectionInfo $ConnectionInfo

            Write-Progress -Activity "Finding subset" -PercentComplete (100 * ($progress.Processed / ($progress.Processed + $progress.ToProcess)))
        }

        # Logic
        $q = "SELECT TOP 1 ps.[Schema], ps.TableName, ps.Type FROM SqlSizer.ProcessingStats ps WHERE ToProcess <> 0 ORDER BY ToProcess DESC"
        $first = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    
        if ($null -eq $first)
        {
            Write-Progress -Activity "Finding subset" -Completed
            break
        }

        $schema = $first.Schema
        $tableName = $first.TableName
        $color = $first.Type

        $table = $tablesGrouped[$schema + ", " + $tableName]
        $signature = $structure.Tables[$table]
        $slice = $structure.GetSliceName($signature)
        $processing = $structure.GetProcessingName($signature)
        
        $keys = ""
        for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
        {
           $keys = $keys + "Key" + $i + ","
        }

        $q = "TRUNCATE TABLE $($slice)"
        $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

        $q = "INSERT INTO  $($slice) " +  "SELECT DISTINCT " + $keys + " Depth FROM $($processing) WHERE Status = 0 AND Type = " + $color + " AND TableName = '" + $tableName + "' and [Schema] = '" + $schema + "'"
        $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    
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
               if ([TableInfo2]::IsIgnored($fk.Schema, $fk.Table, $ignoredTables) -eq $true)
               {
                    continue
               }
               $baseTable = $tablesGrouped[$fk.Schema + ", " + $fk.Table]
               $baseSignature = $structure.Tables[$baseTable]
               $baseProcessing = $structure.GetProcessingName($baseSignature)

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
               $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM $($baseProcessing) p WHERE p.[Type] = " + [int][Color]::Red + " and p.[Schema] = '" + $fk.Schema + "' and p.TableName = '" + $fk.Table + "' and " + $columns +  ")"


               # from
               $join = " INNER JOIN $($slice) s ON "
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
                    $columns = $columns + (Get-ColumnValue -columnName $fkColumn.Name -prefix "f." -dataType $fkColumn.dataType) + " as val" + $i + ","
                    $i += 1
               }

               $select = "SELECT DISTINCT " + $columns + " s.Depth as Depth "
               $sql = $select + $from + $where

               $columns = ""
               for ($i = 0; $i -lt $fk.FkColumns.Count; $i = $i + 1)
               {
                    $columns = $columns + "x.val" + $i + ","
               }

               $forcedColor = $color
               
               if ($null -ne $ColorMap)
               {
                    $item = $ColorMap.Items | Where-Object {($_.SchemaName -eq $fk.Schema) -and ($_.TableName -eq $fk.Table)}
                    if ($null -ne $item)
                    {
                        $forcedColor = [int]$item.ForcedColor
                    }
               }
               $insert = "INSERT INTO $($baseProcessing) SELECT '" + $fk.Schema + "', '" + $fk.Table + "', " + $columns + " " + $forcedColor + ", 0, x.Depth + 1, 0 FROM (" + $sql + ") x"
              
               $insert = $insert + " SELECT @@ROWCOUNT AS Count"
               $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo

               $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.Schema + "' and [TableName] = '" +  $fk.Table + "' and [Type]  = $($forcedColor)"
               $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
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
                if ([TableInfo2]::IsIgnored($fk.FkSchema, $fk.FkTable, $ignoredTables) -eq $true)
                {
                    continue
                }
                $fkTable = $tablesGrouped[$fk.FkSchema + ", " + $fk.FkTable]
                $fkSignature = $structure.Tables[$fkTable]
                $fkProcessing = $structure.GetProcessingName($fkSignature)
 
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
                $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM $($fkProcessing) p WHERE p.[Type] = " + [int][Color]::Yellow +  " and p.[Schema] = '" + $fk.FkSchema + "' and p.TableName = '" + $fk.FkTable + "' and " + $columns +  ")"
                

                # from
                $join = " INNER JOIN $($slice) s ON "
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
                    $columns = $columns + (Get-ColumnValue -columnName $primaryKeyColumn.Name -prefix "f." -dataType $primaryKeyColumn.dataType) + " as val" + $i + ","
                    $i += 1
                }
               
                $select = "SELECT DISTINCT " + $columns + " s.Depth as Depth "
                $sql = $select + $from + $where
                
                
                $columns = ""
                for ($i = 0; $i -lt $primaryKey.Count; $i = $i + 1)
                {
                     $columns = $columns + "x.val" + $i + ","
                }
                
                $insert = "INSERT INTO $($fkProcessing) SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns  + " " + [int][Color]::Yellow +  ", 0, x.Depth + 1, 0 FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"
                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                
                $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.FkSchema + "' and [TableName] = '" +   $fk.FkTable + "' and [Type]  = $([int][Color]::Yellow)"
                $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
             }
           }
        }
        
        # Yellow -> Split into Red and Green
        if ($color -eq [int][Color]::Yellow) 
        {
            $columns = ""
            for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
            {
                $columns = $columns + "s.Key" + $i + ","
            }
            
            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM $($processing) p WHERE p.[Depth] = s.[Depth] and p.[Type] = " + [int][Color]::Red  + "  and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO $($processing) " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Red + ", 0, s.Depth, 0 FROM $($slice) s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "' and [Type] = $([int][Color]::Red)"
            $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM $($processing) p WHERE p.[Depth] = s.[Depth] and p.[Type] = " + [int][Color]::Green  + " and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO $($processing) " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Green + ", 0, s.Depth, 0 FROM $($slice) s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "' and [Type] = $([int][Color]::Green)"
            $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
        }

        # Blue Color
        if ($color -eq [int][Color]::Blue) 
        {
           foreach ($referencedByTable in $table.IsReferencedBy)
           {
             $fks = $referencedByTable.ForeignKeys | Where-Object {($_.Schema -eq $schema) -and ($_.Table -eq $tableName)}
             foreach ($fk in $fks)
             {
                if ([TableInfo2]::IsIgnored($fk.FkSchema, $fk.FkTable, $ignoredTables) -eq $true)
                {
                    continue
                }

                $fkTable = $tablesGrouped[$fk.FkSchema + ", " + $fk.FkTable]
                $fkSignature = $structure.Tables[$fkTable]
                $fkProcessing = $structure.GetProcessingName($fkSignature)
 
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
                $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM $($fkProcessing) p WHERE p.[Type] = " + [int][Color]::Blue +  " and p.[Schema] = '" + $fk.FkSchema + "' and p.TableName = '" + $fk.FkTable + "' and " + $columns +  ")"
                
                
                # from
                $join = " INNER JOIN $($slice) s ON "
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
                    $columns = $columns + (Get-ColumnValue -columnName $primaryKeyColumn.Name -prefix "f." -dataType $primaryKeyColumn.dataType) + " as val" + $i + ","
                    $i += 1
                }
             
                $select = "SELECT DISTINCT " + $columns + " s.Depth as Depth "
                $sql = $select + $from + $where
                
                
                $columns = ""
                for ($i = 0; $i -lt $primaryKey.Count; $i = $i + 1)
                {
                     $columns = $columns + "x.val" + $i + ","
                }
                
                $insert = "INSERT INTO $($fkProcessing) SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns  + " " + [int][Color]::Blue +  ", 0, x.Depth + 1, 0 FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"
                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                
                $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.FkSchema + "' and [TableName] = '" +   $fk.FkTable + "' and [Type] = $([int][Color]::Blue)"
                $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
             }
           }
        }
        
        # Update status
        $q = "UPDATE p SET Status = 1 FROM $($processing) p WHERE [Schema] = '" + $schema + "' and TableName = '" + $tableName + "' and [Type] = " + $color + " and Status = 0 and EXISTS(SELECT 1 FROM $($slice) s WHERE " + $cond + ") SELECT @@ROWCOUNT AS Count"
        $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo 

        # update stats
        $q = "UPDATE SqlSizer.ProcessingStats SET Processed = Processed + " + $results.Count + ", ToProcess = ToProcess - " + $results.Count +  " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "' and [Type] = $($color)"
        $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    }
}