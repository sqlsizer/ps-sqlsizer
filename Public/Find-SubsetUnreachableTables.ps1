function Find-SubsetUnreachableTables
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [Query[]]$Queries,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $reachableTables = New-Object 'System.Collections.Generic.HashSet[string]'
    $processedTableColors = New-Object 'System.Collections.Generic.HashSet[string]'
    $processingQueue = New-Object System.Collections.Generic.Queue"[TableInfo2WithColor]"

    # Add all tables to processing
    foreach ($query in $Queries)
    {
        $item = New-Object TableInfo2WithColor
        $item.SchemaName = $query.Schema
        $item.TableName = $query.Table
        $item.Color = $query.Color

       $null = $processingQueue.Enqueue($item)
    }

    while ($true)
    {
        if ($processingQueue.Count -eq 0)
        {
            break
        }

        $item = $processingQueue.Dequeue()
        $key = $item.SchemaName + "." + $item.TableName + "." + $item.Color

        if ($processedTableColors.Contains($key))
        {
            continue
        }

        $table = $info.Tables.Where(({($_.TableName -eq $item.TableName) -and ($_.SchemaName -eq $item.SchemaName)}))[0]

        if ($item.Color -eq [Color]::Yellow)
        {
            $newItem = New-Object TableInfo2WithColor
            $newItem.SchemaName = $item.SchemaName
            $newItem.TableName = $item.TableName
            $newItem.Color = [Color]::Green
            $null = $processingQueue.Enqueue($newItem)

            $newItem = New-Object TableInfo2WithColor
            $newItem.SchemaName = $item.SchemaName
            $newItem.TableName = $item.TableName
            $newItem.Color = [Color]::Red
            $null = $processingQueue.Enqueue($newItem)
        }

        if ($item.Color -eq [Color]::Red)
        {
            foreach ($fk in $table.ForeignKeys)
            {
                $newItem = New-Object TableInfo2WithColor
                $newItem.SchemaName = $fk.Schema
                $newItem.TableName = $fk.Table
                $newItem.Color = [Color]::Red
                $null = $processingQueue.Enqueue($newItem)
            }
        }

        if (($item.Color -eq [Color]::Green) -or ($item.Color -eq [Color]::Blue))
        {
            foreach ($referencedByTable in $table.IsReferencedBy)
            {
                $fks = $referencedByTable.ForeignKeys | Where-Object {($_.Schema -eq $item.SchemaName) -and ($_.Table -eq $item.TableName)}
                foreach ($fk in $fks)
                {
                    $newItem = New-Object TableInfo2WithColor
                    $newItem.SchemaName = $fk.FkSchema
                    $newItem.TableName = $fk.FkTable
                    if ($item.Color -eq [Color]::Green)
                    {
                        $newItem.Color = [Color]::Yellow
                    }
                    if ($item.Color -eq [Color]::Blue)
                    {
                        $newItem.Color = [Color]::Blue
                    }
                    $null = $processingQueue.Enqueue($newItem)
                }
            }
        }

        $null = $reachableTables.Add($item.SchemaName + "." + $item.TableName)
        $null = $processedTableColors.Add($key)
    }

    $toReturn = @()
    foreach ($table in $info.Tables)
    {
        $key = $table.SchemaName + "." + $table.TableName

        if ($reachableTables.Contains($key) -eq $false)
        {   
            $item = New-Object TableInfo2
            
            $item.SchemaName = $table.SchemaName
            $item.TableName = $table.TableName

            $toReturn += $item
        }
    }

    return $toReturn
}