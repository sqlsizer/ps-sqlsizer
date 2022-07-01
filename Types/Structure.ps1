class Structure
{
    [DatabaseInfo] $DatabaseInfo
    [System.Collections.Generic.Dictionary[String, ColumnInfo[]]] $Signatures
    [System.Collections.Generic.Dictionary[TableInfo, String]] $Tables

    Structure(
        [DatabaseInfo]$DatabaseInfo
    )
    {
        $this.DatabaseInfo = $DatabaseInfo
        $this.Signatures = New-Object System.Collections.Generic.Dictionary"[String, ColumnInfo[]]"
        $this.Tables = New-Object System.Collections.Generic.Dictionary"[TableInfo, String]"

        foreach ($table in $this.DatabaseInfo.Tables) {

            if ($table.PrimaryKey.Count -eq 0)
            {
                continue
            }

            $signature = $this.GetTablePrimaryKeySignature($table)
            $this.Tables[$table] = $signature

            if ($this.Signatures.ContainsKey($signature) -eq $false)
            {
                $this.Signatures.Add($signature, $table.PrimaryKey)
            }
        }
    }

    [string] GetProcessingName([string] $Signature) {
        return "SqlSizer.Processing" + $Signature
    }

    [string] GetSliceName([string] $Signature) {
        return "SqlSizer.Slice" + $Signature
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