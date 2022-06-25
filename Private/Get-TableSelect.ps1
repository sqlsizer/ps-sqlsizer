function Get-TableSelect
{
    param (
        [bool]$Raw,
        [string]$Prefix,
        [TableInfo]$TableInfo,
        [TableInfo2[]]$IgnoredTables
    )
    
    $select = ""
    $j = 0
    for ($i = 0; $i -lt $TableInfo.Columns.Count; $i++)
    {
        $column = $TableInfo.Columns[$i]
        $columnName = $column.Name

        if (($column.IsComputed -eq $true) -or ($column.IsGenerated -eq $true) -or ($column.DataType -eq "timestamp"))
        {
            continue
        }
        else
        {
            if ($j -gt 0)
            {
                $select += ","
            }

            $include = $true

            foreach ($fk in $TableInfo.ForeignKeys)
            {
                if ([TableInfo2]::IsIgnored($fk.Schema, $fk.Table, $ignoredTables) -eq $true)
                {
                    foreach ($fkColumn in $fk.FkColumns)
                    {
                        if ($fkColumn.Name -eq $columnName)
                        {
                            $include = $false
                            break
                        }
                    }
                }
            }

            if ($Raw)
            {
                if (($Prefix -ne $null) -and ($Prefix -ne ""))
                {
                    $select +=  " $Prefix[" + $columnName + "]"
                }
                else
                {
                    $select +=  " [" + $columnName + "]"
                }
            }
            else
            {
                if ($include)
                {
                    $select += Get-ColumnValue -columnName $columnName -dataType $column.DataType -prefix "$Prefix" -newName $columnName
                }
                else
                {
                    $select += " NULL "
                }
            }

            $j += 1
        }
    }

    $select
}
