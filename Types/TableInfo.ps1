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