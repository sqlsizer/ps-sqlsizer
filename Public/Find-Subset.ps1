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
    $percent = 0
    
    $tablesIndex = New-Object System.Collections.Generic.Dictionary"[String, Object]"

    $i = 0
    foreach ($table in $info.Tables)
    {
        $tablesIndex["$($table.SchemaName).$($table.TableName)"] = $i
        $i += 1
    }

    while ($true)
    { 
        # Progress handling
        $totalSeconds = (New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds
        if ($totalSeconds -gt ($lastTotalSeconds + $interval))
        {
            $lastTotalSeconds = $totalSeconds
            $progress = Get-SubsetProgress -Database $Database -ConnectionInfo $ConnectionInfo
            $percent = (100 * ($progress.Processed / ($progress.Processed + $progress.ToProcess)))
            Write-Progress -Activity "Finding subset" -PercentComplete $percent
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

        Write-Progress -Activity "Finding subset" -CurrentOperation  "Slice for $($schema).$($tableName) table is being processed with color $([Color]$color)" -PercentComplete $percent

        $table = $tablesGrouped[$schema + ", " + $tableName]
        $signature = $structure.Tables[$table]
        $slice = $structure.GetSliceName($signature)
        $processing = $structure.GetProcessingName($signature)
        $index = $tablesIndex[$schema + "." + $tableName]

       
        $keys = ""
        for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
        {
           $keys = $keys + "Key" + $i + ","
        }

        $q = "TRUNCATE TABLE $($slice)"
        $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

        $q = "INSERT INTO  $($slice) " +  "SELECT DISTINCT " + $keys + " [Source] FROM $($processing) WHERE [Status] = 0 AND [Type] = " + $color + " AND [TableName] = '" + $tableName + "' and [Schema] = '" + $schema + "'"
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

               $newColor = $color
               if ($null -ne $ColorMap)
               {
                    $item = $ColorMap.Items | Where-Object {($_.SchemaName -eq $fk.Schema) -and ($_.TableName -eq $fk.Table)}
                    if (($null -ne $item) -and ($null -ne $item.ForcedColor))
                    {
                        $newColor = [int]$item.ForcedColor.Color
                    }
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
               $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM $($baseProcessing) p WHERE p.[Type] = " + $newColor + " and p.[Schema] = '" + $fk.Schema + "' and p.TableName = '" + $fk.Table + "' and " + $columns +  ")"

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
                   if ($columns -ne "")
                   {
                     $columns += ","
                   }
                   $columns = $columns + (Get-ColumnValue -columnName $fkColumn.Name -prefix "f." -dataType $fkColumn.dataType) + " as val" + $i 
                   $i += 1
               }

               $select = "SELECT DISTINCT " + $columns
               $sql = $select + $from + $where

               $columns = ""
               for ($i = 0; $i -lt $fk.FkColumns.Count; $i = $i + 1)
               {
                    $columns = $columns + "x.val" + $i + ","
               }
             
               $insert = "INSERT INTO $($baseProcessing) SELECT '" + $fk.Schema + "', '" + $fk.Table + "', " + $columns + " " + $newColor + ", 0, $($index) FROM (" + $sql + ") x"
              
               $insert = $insert + " SELECT @@ROWCOUNT AS Count"
               $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo

               if ($results.Count -gt 0)
               {
                    $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.Schema + "' and [TableName] = '" +  $fk.Table + "' and [Type]  = $($newColor)"
                    $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
               }
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

                $top = $null
                if ($null -ne $ColorMap)
                {
                     $item = $ColorMap.Items | Where-Object {($_.SchemaName -eq $fk.FkSchema) -and ($_.TableName -eq $fk.FkTable)}
                     if (($null -ne $item) -and ($null -ne $item.Condition))
                     {
                         $top = [int]$item.Condition.Top
                     }
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
                $where += "  AND NOT EXISTS(SELECT * FROM $($fkProcessing) p WHERE p.[Source] = $($index) AND p.[Type] = " + [int][Color]::Yellow +  " and p.[Schema] = '" + $fk.FkSchema + "' and p.TableName = '" + $fk.FkTable + "')"
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
                    if ($columns -ne "")
                    {
                        $columns += ", "
                    }
                    $columns = $columns + (Get-ColumnValue -columnName $primaryKeyColumn.Name -prefix "f." -dataType $primaryKeyColumn.dataType) + " as val" + $i 
                    $i += 1
                }

                $topPhrase = " "

                if ($null -ne $top)
                {
                    $topPhrase = " TOP $($top) "
                }
               
                $select = "SELECT DISTINCT " + $topPhrase + $columns 
                $sql = $select + $from + $where
                
                $columns = ""
                for ($i = 0; $i -lt $primaryKey.Count; $i = $i + 1)
                {
                     $columns = $columns + "x.val" + $i + ","
                }
                
                $insert = "INSERT INTO $($fkProcessing) SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns  + " " + [int][Color]::Yellow +  ", 0, $($index) FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"

                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                if ($results.Count -gt 0)
                {
                    $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.FkSchema + "' and [TableName] = '" +   $fk.FkTable + "' and [Type]  = $([int][Color]::Yellow)"
                    $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
                }
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
            $where = " WHERE NOT EXISTS(SELECT * FROM $($processing) p WHERE p.[Type] = " + [int][Color]::Red  + "  and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO $($processing) " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Red + ", 0, s.Source FROM $($slice) s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update stats
            $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "' and [Type] = $([int][Color]::Red)"
            $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM $($processing) p WHERE p.[Type] = " + [int][Color]::Green  + " and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO $($processing) " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Green + ", 0, s.Source FROM $($slice) s" + $where
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
             
                $select = "SELECT DISTINCT " + $columns
                $sql = $select + $from + $where
                
                
                $columns = ""
                for ($i = 0; $i -lt $primaryKey.Count; $i = $i + 1)
                {
                     $columns = $columns + "x.val" + $i + ","
                }
                
                $insert = "INSERT INTO $($fkProcessing) SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns  + " " + [int][Color]::Blue +  ", 0,  $($index) FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"
                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                
                if ($results.Count -gt 0)
                {
                    $q = "UPDATE SqlSizer.ProcessingStats SET ToProcess = ToProcess + " + $results.Count + " WHERE [Schema] = '" +  $fk.FkSchema + "' and [TableName] = '" +   $fk.FkTable + "' and [Type] = $([int][Color]::Blue)"
                    $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
                }
             }
           }
        }
        
        # Update status
        $q = "UPDATE p SET Status = 1 FROM $($processing) p INNER JOIN $($slice) s ON $($cond) and ((s.[Source] = p.[Source]) or (s.[Source] IS NULL and p.[Source] IS NULL)) WHERE [Schema] = '" + $schema + "' and TableName = '" + $tableName + "' and [Type] = " + $color + " and Status = 0 SELECT @@ROWCOUNT AS Count"
        $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo 

        # update stats
        if ($results.Count -gt 0)
        {
            $q = "UPDATE SqlSizer.ProcessingStats SET Processed = Processed + " + $results.Count + ", ToProcess = ToProcess - " + $results.Count +  " WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "' and [Type] = $($color)"
            $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
        }
    }
}