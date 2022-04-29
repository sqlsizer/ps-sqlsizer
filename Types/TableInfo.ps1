class DatabaseInfo
{
    [TableInfo[]]$Tables
    [int]$PrimaryKeyMaxSize
}

class TableInfo
{
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


    [string] ToString() {
      return "$($this.SchemaName).$($this.TableName)"
   }
}

class ColumnInfo
{
    [string]$Name
    [string]$DataType
    [bool]$IsNullable
    [bool]$IsComputed
    [bool]$IsGenerated
}


class TableFk
{
    [string]$Name
    [string]$FkSchema
    [string]$FkTable

    [string]$Schema
    [string]$Table

    [ColumnInfo[]]$FkColumns
    [ColumnInfo[]]$Columns
}