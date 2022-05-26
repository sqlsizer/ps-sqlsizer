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
        $q = "SELECT TOP 1
                [Schema]
               ,[TableName]
               ,[ToProcess]
               ,[Color]
               ,[Depth]
            FROM 
                [SqlSizer].[Operations]
            WHERE 
                [Processed] = 0
            GROUP BY 
                [Schema], [TableName], [ToProcess], [Depth], [Color]
            ORDER BY 
                [Depth] ASC, [ToProcess] DESC"
        $first = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    
        if ($null -eq $first)
        {
            Write-Progress -Activity "Finding subset" -Completed
            break
        }

        $schema = $first.Schema
        $tableName = $first.TableName
        $color = $first.Color
        $depth = $first.Depth

        Write-Progress -Activity "Finding subset" -CurrentOperation  "Slice for $($schema).$($tableName) table is being processed with color $([Color]$color)" -PercentComplete $percent

        $table = $tablesGrouped[$schema + ", " + $tableName]
        $signature = $structure.Tables[$table]
        $slice = $structure.GetSliceName($signature)
        $processing = $structure.GetProcessingName($signature)
        
        $index = $table.Id
       
        $keys = ""
        for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
        {
           $keys = $keys + "Key" + $i + ","
        }

        $q = "TRUNCATE TABLE $($slice)"
        $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

        $q = "INSERT INTO  $($slice) " +  "SELECT DISTINCT " + $keys + " [Source], [Depth], [Fk] FROM $($processing) WHERE [Depth] = $($depth) AND [Color] = " + $color + " AND [TableName] = '" + $tableName + "' and [Schema] = '" + $schema + "'"
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
            
        # Red and Purple color
        if (($color -eq [int][Color]::Red) -or ($color -eq [int][Color]::Purple))
        {
           foreach ($fk in $table.ForeignKeys)
           {
               if ([TableInfo2]::IsIgnored($fk.Schema, $fk.Table, $ignoredTables) -eq $true)
               {
                    continue
               }

               $newColor = [int][Color]::Red

               if ($null -ne $ColorMap)
               {
                    $items = $ColorMap.Items | Where-Object {($_.SchemaName -eq $fk.Schema) -and ($_.TableName -eq $fk.Table)}
                    $items = $items | Where-Object {($null -eq $_.Condition) -or ((($_.Condition.SourceSchemaName -eq $fk.FkSchema) -or ("" -eq $_.Condition.SourceSchemaName)) -and (($_.Condition.SourceTableName -eq $fk.FkTable) -or ("" -eq $_.Condition.SourceTableName)))}
                    if (($null -ne $items) -and ($null -ne $items.ForcedColor))
                    {
                        $newColor = [int]$items.ForcedColor.Color
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
               $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM $($baseProcessing) p WHERE p.[Color] = " + $newColor + " and p.[Schema] = '" + $fk.Schema + "' and p.TableName = '" + $fk.Table + "' and " + $columns +  ")"

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

               $select = "SELECT DISTINCT " + $columns + ", s.Depth"
               $sql = $select + $from + $where

               $columns = ""
               for ($i = 0; $i -lt $fk.FkColumns.Count; $i = $i + 1)
               {
                    $columns = $columns + "x.val" + $i + ","
               }
             
               $insert = "INSERT INTO $($baseProcessing) SELECT '" + $fk.Schema + "', '" + $fk.Table + "', " + $columns + " " + $newColor + ", $($index), x.Depth + 1, $($fk.Id) FROM (" + $sql + ") x"
              
               $insert = $insert + " SELECT @@ROWCOUNT AS Count"
               $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo

               if ($results.Count -gt 0)
               {
                    $q = "INSERT INTO SqlSizer.Operations VALUES('" +  $fk.Schema + "', '" + $fk.Table + "', $($newColor), $($results.Count),  0, $($index), $($depth + 1), GETDATE())"
                    $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
               }
            }
        }

        # Green/Purple/Blue Color
        if (($color -eq [int][Color]::Green) -or ($color -eq [int][Color]::Purple) -or ($color -eq [int][Color]::Blue))
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
                $maxDepth = $null
                $newColor = $null

                # default new color
                if ($color -eq [int][Color]::Green)
                {
                    $newColor = [int][Color]::Yellow
                }

                if ($color -eq [int][Color]::Purple)
                {
                    $newColor = [int][Color]::Red
                }

                if ($color -eq [int][Color]::Blue)
                {
                    $newColor = [int][Color]::Blue
                }

                # forced color from color map
                if ($null -ne $ColorMap)
                {
                     $items = $ColorMap.Items | Where-Object {($_.SchemaName -eq $fk.FkSchema) -and ($_.TableName -eq $fk.FkTable)}
                     $items = $items | Where-Object {($null -eq $_.Condition) -or ($_.Condition.FkName -eq $fk.Name) -or ((($_.Condition.SourceSchemaName -eq $fk.Schema) -or ("" -eq $_.Condition.SourceSchemaName)) -and (($_.Condition.SourceTableName -eq $fk.Table) -or ("" -eq $_.Condition.SourceTableName)))}
                     
                     if (($null -ne $items) -and ($null -ne $items.Condition))
                     {
                         $top = [int]$items.Condition.Top
                     }

                     if (($null -ne $items) -and ($null -ne $items.Condition) -and ($items.Condition.Top -ne -1))
                     {
                         $top = [int]$items.Condition.Top
                     }

                     if (($null -ne $items) -and ($null -ne $items.Condition) -and ($items.Condition.MaxDepth -ne -1))
                     {
                         $maxDepth = [int]$items.Condition.MaxDepth
                     }

                     if (($null -ne $items) -and ($null -ne $items.ForcedColor))
                     {
                         $newColor = [int]$items.ForcedColor.Color
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
                $where = " WHERE " + $fk.FkColumns[0].Name +  " IS NOT NULL AND NOT EXISTS(SELECT * FROM $($fkProcessing) p WHERE p.[Color] = " + $newColor +  " and p.[Schema] = '" + $fk.FkSchema + "' and p.TableName = '" + $fk.FkTable + "' and " + $columns +  ")"
                
                # prevent go-back
                $where += " AND s.Source <> $($fkTable.Id)"

                if ($null -ne $maxDepth)
                {
                    $where += " AND s.Depth <= $($maxDepth)"
                }
                
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

                if (($null -ne $top) -and ($top -ne -1))
                {
                    $topPhrase = " TOP $($top) "
                }
               
                $select = "SELECT DISTINCT " + $topPhrase + $columns + ", s.Depth"
                $sql = $select + $from + $where
                
                $columns = ""
                for ($i = 0; $i -lt $primaryKey.Count; $i = $i + 1)
                {
                     $columns = $columns + "x.val" + $i + ","
                }
                
                $insert = "INSERT INTO $($fkProcessing) SELECT '" + $fk.FkSchema + "', '" + $fk.FkTable + "', " + $columns  + " " + $newColor +  ", $($index), x.Depth + 1, $($fk.Id) FROM (" + $sql + ") x"
                
                $insert = $insert + " SELECT @@ROWCOUNT AS Count"

                $results = Execute-SQL -Sql $insert -Database $database -ConnectionInfo $ConnectionInfo
                if ($results.Count -gt 0)
                {
                    $q = "INSERT INTO SqlSizer.Operations VALUES('" +  $fk.FkSchema + "', '" + $fk.FkTable + "', $newColor, $($results.Count), 0, $($index), $($depth + 1), GETDATE())"
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
            $where = " WHERE NOT EXISTS(SELECT * FROM $($processing) p WHERE p.[Color] = " + [int][Color]::Red  + "  and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO $($processing) " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Red + ", s.Source, s.Depth, s.Fk FROM $($slice) s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update opeations
            $q = "INSERT INTO SqlSizer.Operations VALUES('" +  $schema + "', '" + $tableName + "', $([int][Color]::Red), $($results.Count), 0, $($table.Id), $($depth), GETDATE())"
            $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
            
            # insert 
            $where = " WHERE NOT EXISTS(SELECT * FROM $($processing) p WHERE p.[Color] = " + [int][Color]::Green  + " and p.[Schema] = '" + $schema + "' and p.[TableName] = '" + $tableName + "' and " + $cond + ") SELECT @@ROWCOUNT AS Count"
            $q = "INSERT INTO $($processing) " +  "SELECT '" + $schema + "', '" +  $tableName +  "', " + $columns + " " + [int][Color]::Green + ", s.Source, s.Depth, s.Fk FROM $($slice) s" + $where
            $results = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo

            # update opeations
            $q = "INSERT INTO SqlSizer.Operations VALUES('" +  $schema + "', '" + $tableName + "', $([int][Color]::Green), $($results.Count), 0, $($table.Id), $($depth), GETDATE())"
            $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
        }

        # update operations
        $q = "UPDATE SqlSizer.Operations SET Processed = 1 WHERE [Schema] = '" +  $schema + "' and [TableName] = '" +  $tableName + "' and [Color] = $($color) and [Depth] = $($depth)"
        $null = Execute-SQL -Sql $q -Database $database -ConnectionInfo $ConnectionInfo
    }
}