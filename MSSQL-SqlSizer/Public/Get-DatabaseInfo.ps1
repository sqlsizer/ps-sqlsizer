function Get-DatabaseInfo
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [bool]$MeasureSize,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\TablesInfo.sql")
    $rows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $result = New-Object -TypeName DatabaseInfo

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\TablesPrimaryKeys.sql")
    $primaryKeyRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $primaryKeyRowsGrouped = $primaryKeyRows | Group-Object -Property schema, table -AsHashTable -AsString

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\TablesColumns.sql")
    $columnsRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $columnsRowsGrouped = $columnsRows | Group-Object -Property schema, table -AsHashTable -AsString

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\TablesForeignKeys.sql")
    $foreignKeyRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $foreignKeyRowsGrouped = $foreignKeyRows | Group-Object -Property fk_schema, fk_table -AsHashTable -AsString

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\TablesIndexes.sql")
    $indexesRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $indexesRowsGrouped = $indexesRows | Group-Object -Property schema, table -AsHashTable -AsString

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\TableViewDepenencies.sql")
    $depRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $depRowsGrouped = $depRows | Group-Object -Property referenced_schema_name, referenced_entity_name -AsHashTable -AsString

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\ViewsInfo.sql")
    $viewsInfoRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\SchemasInfo.sql")
    $schemasRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    if ($true -eq $MeasureSize)
    {
        $statsRows = Invoke-SqlcmdEx -Sql ("EXEC sp_spaceused") -Database $Database -ConnectionInfo $ConnectionInfo
        $result.DatabaseSize = $statsRows[0]["database_size"]
    }

    foreach ($row in $viewsInfoRows)
    {
        $view = New-Object -TypeName ViewInfo
        $view.SchemaName = $row["schema"]
        $view.ViewName = $row["view"]
        $result.Views += $view
    }

    foreach ($row in $rows)
    {
        $table = New-Object -TypeName TableInfo
        $table.SchemaName = $row["schema"]
        $table.TableName = $row["table"]
        $table.IsIdentity = $row["identity"]
        $table.IsHistoric = $row["is_historic"]
        $table.HistoryOwner = $row["history_owner"]
        $table.HistoryOwnerSchema = $row["history_owner_schema"]
        $table.IsReferencedBy = @()

        if ($true -eq $MeasureSize)
        {
            $statsRow = Invoke-SqlcmdEx -Sql ("EXEC sp_spaceused [" + $table.SchemaName + "." + $table.TableName + "]") -Database $Database -ConnectionInfo $ConnectionInfo
            $stats = New-Object -TypeName TableStatistics

            $stats.Rows = $statsRow["rows"]
            $stats.DataKB = $statsRow["data"].Trim(' KB')
            $stats.IndexSize = $statsRow["index_size"].Trim(' KB')
            $stats.UnusedKB = $statsRow["unused"].Trim(' KB')
            $stats.ReservedKB = $statsRow["reserved"].Trim(' KB')

            $table.Statistics = $stats
        }

        $key = $table.SchemaName + ", " + $table.TableName
        $tableKey = $primaryKeyRowsGrouped[$key]

        foreach ($tableKeyColumn in $tableKey)
        {
            $pkColumn = New-Object -TypeName ColumnInfo
            $pkColumn.Name = $tableKeyColumn["column"]
            $pkColumn.DataType = $tableKeyColumn["dataType"]
            $pkColumn.Length = $tableKeyColumn["length"]
            $pkColumn.IsNullable = $false
            $pkColumn.IsComputed = $false
            $table.PrimaryKey += $pkColumn
        }

        $tableColumns = $columnsRowsGrouped[$key]

        foreach ($tableColumn in $tableColumns)
        {
            $column = New-Object -TypeName ColumnInfo
            $column.Name = $tableColumn["column"]
            $column.DataType = $tableColumn["dataType"]
            $column.IsComputed = $tableColumn["isComputed"]
            $column.IsGenerated = $tableColumn["isGenerated"]
            $column.IsNullable = $tableColumn["isNullable"] -eq "YES"
            $table.Columns += $column
        }

        $tableForeignKeys = $foreignKeyRowsGrouped[$key]

        $tableForeignKeysGrouped = $tableForeignKeys | Group-Object -Property fk_name

        foreach ($item in $tableForeignKeysGrouped)
        {
            $fk = New-Object -TypeName TableFk
            $fk.Name = $item.Name

            foreach ($column in $item.Group)
            {
                $fk.Schema = $column["schema"]
                $fk.Table = $column["table"]
                $fk.FkSchema = $column["fk_schema"]
                $fk.FkTable = $column["fk_table"]

                $fkColumn = New-Object -TypeName ColumnInfo
                $fkColumn.Name = $column["fk_column"]
                $fkColumn.DataType = $column["fk_column_data_type"]
                $fkColumn.IsNullable = $column["fk_column_is_nullable"]
                $fkColumn.IsComputed = $false

                $baseColumn = New-Object -TypeName ColumnInfo
                $baseColumn.Name = $column["column"]
                $baseColumn.DataType = $column["fk_column_data_type"]
                $baseColumn.IsNullable = $false
                $baseColumn.IsComputed = $false

                $fk.Columns += $baseColumn
                $fk.FkColumns += $fkColumn
            }

            $table.ForeignKeys += $fk
        }

        if ($null -ne $indexesRowsGrouped)
        {
            $indexesForTable = $indexesRowsGrouped[$key]
            $indexesForTableGrouped = $indexesForTable | Group-Object -Property index

            foreach ($item in $indexesForTableGrouped)
            {
                $index = New-Object -TypeName Index
                $index.Name = $item.Name

                foreach ($column in $item.Group)
                {
                    $index.Columns += $column["column"]
                }

                $table.Indexes += $index
            }
        }

        if ($null -ne $depRowsGrouped)
        {
            $viewsForTable = $depRowsGrouped[$key]
            $table.Views = @()

            foreach ($item in $viewsForTable)
            {
                $view = New-Object ViewInfo
                $view.SchemaName = $item.view_schema_name
                $view.ViewName = $item.view_name
                $table.Views += $view
            }
        }

        $result.Tables += $table
    }

    $primaryKeyMaxSize = 0

    $tablesGrouped = @{}
    foreach ($table in $result.Tables)
    {
        $tablesGrouped[$table.SchemaName + ", " + $table.TableName] = $table
    }

    $tablesGroupedByHistory = $result.Tables | Group-Object -Property HistoryOwnerSchema, HistoryOwner

    foreach ($table in $result.Tables)
    {
        if ($table.PrimaryKey.Count -gt $primaryKeyMaxSize)
        {
            $primaryKeyMaxSize = $table.PrimaryKey.Count
        }

        $table.HasHistory = $false
        if ($null -ne $tablesGroupedByHistory[$table.SchemaName + ", " + $table.TableName])
        {
            $table.HasHistory = $true
        }

        foreach ($fk in $table.ForeignKeys)
        {
            $schema = $fk.Schema
            $tableName = $fk.Table

            $primaryTable = $tablesGrouped[$schema + ", " + $tableName]

            if ($primaryTable.IsReferencedBy.Contains($table) -eq $false)
            {
                $primaryTable.IsReferencedBy += $table
            }

        }
    }

    $result.PrimaryKeyMaxSize = $primaryKeyMaxSize

    foreach ($row in $schemasRows)
    {
        $result.AllSchemas += $row.Name
    }

    return $result
}

