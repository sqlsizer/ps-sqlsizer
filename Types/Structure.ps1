class Structure
{
    [DatabaseInfo] $_databaseInfo
    [System.Collections.Generic.Dictionary[String, ColumnInfo[]]] $_signatures
    [System.Collections.Generic.Dictionary[TableInfo, String]] $_tables

    Structure(
        [DatabaseInfo]$DatabaseInfo
    )
    {
        $this._databaseInfo = $DatabaseInfo    
        $this._signatures = New-Object System.Collections.Generic.Dictionary"[String, ColumnInfo[]]"
        $this._tables = New-Object System.Collections.Generic.Dictionary"[TableInfo, String]"
    }

    [void] Init() { 

        foreach ($table in $this._databaseInfo.Tables) {
            $signature = $this.GetTablePrimaryKeySignature($table)
            $this._tables[$table] = $signature

            if ($this._signatures.ContainsKey($signature) -eq $false)
            {
                $this._signatures.Add($signature, $table.PrimaryKey)
            }
        }
    }

    [string] GetProcessingName([string] $signature) {
        return "SqlSizer.Processing" + $signature
    }

    [string] GetSliceName([string] $signature) {
        return "SqlSizer.Slice" + $signature
    }

    [string] GetTablePrimaryKeySignature([TableInfo]$Table) {
        $result = ""
        foreach ($pkColumn in $Table.PrimaryKey)
        {
            $result += "__" + $pkColumn.DataType 
            if (($null -ne $pkColumn.Length) -and ("" -ne $pkColumn.Length))
            {
                $result += "_" + $pkColumn.Length
            }
        }
        return $result
    }
}