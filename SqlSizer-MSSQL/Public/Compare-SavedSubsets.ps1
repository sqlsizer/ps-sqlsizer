function Compare-SavedSubsets
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$SourceDatabase,

        [Parameter(Mandatory=$true)]
        [string]$TargetDatabase,

        [Parameter(Mandatory=$true)]
        [string]$SourceSubsetGuid,

        [Parameter(Mandatory=$true)]
        [string]$TargetSubsetGuid,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    #TODO: make it faster someday

    $sourceTables = Get-SavedSubsetTables -Database $SourceDatabase -SubsetGuid $SourceSubsetGuid -ConnectionInfo $ConnectionInfo
    $targetTables = Get-SavedSubsetTables -Database $TargetDatabase -SubsetGuid $TargetSubsetGuid -ConnectionInfo $ConnectionInfo

    $newTables = @()
    $removedTables = @()

    # find newTables
    foreach ($destinationTable in $targetTables)
    {
        $found = $false
        foreach ($sourceTable in $sourceTables)
        {
            if (($sourceTable.SchemaName -eq $destinationTable.SchemaName) -and ($sourceTable.TableName -eq $destinationTable.TableName))
            {
                $found = $true
                break
            }
        }

        if ($found -eq $false)
        {
            $newTables += $destinationTable
        }
    }

    # find removedTables
    foreach ($sourceTable in $sourceTables)
    {
        $found = $false
        foreach ($destinationTable in $targetTables)
        {
            if (($sourceTable.SchemaName -eq $destinationTable.SchemaName) -and ($sourceTable.TableName -eq $destinationTable.TableName))
            {
                $found = $true
                break
            }
        }

        if ($found -eq $false)
        {
            $removedTables += $sourceTable
        }
    }

    # find changed and new table data
    $changed = @()
    $new = @()
    foreach ($sourceTable in $sourceTables)
    { 
        $found = $false
        foreach ($destinationTable in $targetTables)
        {
            if (($sourceTable.SchemaName -eq $destinationTable.SchemaName) -and ($sourceTable.TableName -eq $destinationTable.TableName))
            {
                $found = $true
                break
            }
        }

        if ($found -eq $true)
        {
            $keys = @()
            $conds = @()
            for ($i = 0; $i -lt $sourceTable.PrimaryKeySize; $i++)
            {
                $keys += "d.Key$i as Key$i"
                $conds += "d.Key$i = s.Key$i"
            }

            #query database to find changes to data based on sha hash
            $sql = "SELECT $([string]::Join(',', $keys))
                    FROM $($DesinationDatabase).[SqlSizerHistory].[SubsetTableRow_$($sourceTable.PrimaryKeySize)] d
                    INNER JOIN $($SourceDatabase).[SqlSizerHistory].[SubsetTableRow_$($sourceTable.PrimaryKeySize)] s ON $([string]::Join(' AND ', $conds))
                    WHERE d.Hash <> s.Hash AND d.TableId = $($destinationTable.TableId) AND s.TableId = $($sourceTable.TableId)"
            
            $changeRows = Invoke-SqlcmdEx -Sql $sql -Database $SourceDatabase -ConnectionInfo $ConnectionInfo

            foreach ($changeRow in $changeRows)
            {
                $key = @()
                foreach ($item in $changeRow)
                {
                    $key += $item
                }

                $changed += [pscustomobject] @{
                    SchemaName = $sourceTable.SchemaName
                    TableName = $sourceTable.TableName
                    Key = $key
                }
            }

            #query database to find new data
            $sql = "SELECT $([string]::Join(',', $keys))
                    FROM $($DesinationDatabase).[SqlSizerHistory].[SubsetTableRow_$($sourceTable.PrimaryKeySize)] d
                    LEFT JOIN $($SourceDatabase).[SqlSizerHistory].[SubsetTableRow_$($sourceTable.PrimaryKeySize)] s ON s.TableId = $($sourceTable.TableId) AND $([string]::Join(' AND ', $conds))
                    WHERE s.Key0 IS NULL AND d.TableId = $($destinationTable.TableId)"
            $newRows = Invoke-SqlcmdEx -Sql $sql -Database $SourceDatabase -ConnectionInfo $ConnectionInfo

            foreach ($newRow in $newRows)
            {
                $key = @()
                foreach ($item in $newRow)
                {
                    $key += $item
                }

                $new += [pscustomobject] @{
                    SchemaName = $sourceTable.SchemaName
                    TableName = $sourceTable.TableName
                    Key = $key
                }
            }
        }
    }

    $result = [pscustomobject]@{
        NewTablesData = $newTables
        RemovedTablesData = $removedTables
        ChangedData = $changed
        AddedData = $new
    }

    return $result

}