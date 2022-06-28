function Get-TableSelect
{
    param (
        [bool]$Raw,
        [string]$Prefix,
        [TableInfo]$TableInfo,
        [TableInfo2[]]$IgnoredTables,
        [bool]$ConvertBit,
        [bool]$AddAs,
        [bool]$Array = $false
    )
    
    $result = @()

    $j = 0
    for ($i = 0; $i -lt $TableInfo.Columns.Count; $i++)
    {
        $select = ""
        $column = $TableInfo.Columns[$i]
        $columnName = $column.Name

        if (($column.IsComputed -eq $true) -or ($column.IsGenerated -eq $true) -or ($column.DataType -eq "timestamp"))
        {
            continue
        }
        else
        {
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

            if ($include)
            {
                $select += Get-ColumnValue -ColumnName $columnName -DataType $column.DataType -Prefix "$Prefix" -ConvertBit $ConvertBit -Conversion $(!$Raw)
            }
            else
            {
                $select += " NULL "
            }

            if ($AddAs)
            {
                $select +=  " as [$columnName]"
            }
            
            $j += 1
            $result += $select
        }
    }

    if ($Array)
    {
        return $result
    }
    else
    {
        return [string]::join(', ', $result)
    }
}
