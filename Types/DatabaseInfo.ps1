class DatabaseInfo
{
    [TableInfo[]]$Tables
    [string[]]$AllSchemas
    [int]$PrimaryKeyMaxSize
    [string]$DatabaseSize
}

class TableInfo2
{
    [string]$SchemaName
    [string]$TableName

    static [bool] IsIgnored([string] $schemaName, [string] $tableName, [TableInfo2[]] $ignoredTables)
    {
        $result = $false

        foreach ($ignoredTable in $ignoredTables)
        {
            if (($ignoredTable.SchemaName -eq $schemaName) -and ($ignoredTable.TableName -eq $tableName))
            {
                $result = $true
                break
            }
        }

        return $result
    }

    [string] ToString() {
        return "$($this.SchemaName).$($this.TableName)"
     }
}

class TableInfo2WithColor
{
    [string]$SchemaName
    [string]$TableName
    [Color]$Color
}

class SubsettingTableResult
{
    [string]$SchemaName
    [string]$TableName
    [long]$RowCount
}

class SubsettingProcess
{
    [long]$ToProcess
    [long]$Processed
}

class TableStatistics
{
    [long]$Rows
    [long]$ReservedKB
    [long]$DataKB
    [long]$IndexSize
    [long]$UnusedKB

    [string] ToString() {
        return "$($this.Rows) rows  => [$($this.DataKB) used of $($this.ReservedKB) reserved KB, $($this.IndexSize) index KB]"
     }
}

class TableInfo
{
    [int]$Id
    [string]$SchemaName
    [string]$TableName
    
    [bool]$IsIdentity
    [bool]$IsHistoric
    [bool]$HasHistory
    [string]$HistoryOwner
    [string]$HistoryOwnerSchema
    
    [ColumnInfo[]]$PrimaryKey
    [ColumnInfo[]]$Columns

    [Tablefk[]]$ForeignKeys
    [TableInfo[]]$IsReferencedBy

    [string[]]$Views

    [TableStatistics]$Statistics

    [Index[]]$Indexes

    [string] ToString() {
      return "$($this.SchemaName).$($this.TableName)"
    }
}

class Index 
{
    [string]$Name
    [string[]]$Columns
}

class ColumnInfo
{
    [string]$Name
    [string]$DataType
    [string]$Length
    [bool]$IsNullable
    [bool]$IsComputed
    [bool]$IsGenerated

    [string] ToString() {
        return $this.Name;
    }
}


class TableFk
{
    [int]$Id
    [string]$Name
    [string]$FkSchema
    [string]$FkTable

    [string]$Schema
    [string]$Table

    [ColumnInfo[]]$FkColumns
    [ColumnInfo[]]$Columns
}