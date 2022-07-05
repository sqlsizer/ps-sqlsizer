function Get-ColumnValue
{
    param
    (
        [string]$ColumnName,
        [string]$DataType,
        [string]$Prefix,
        [bool]$Conversion,
        [bool]$OnlyXml
    )

    if ($Conversion -eq $false)
    {
        return "$($Prefix)[" + $ColumnName + "]"
    }

    if (($OnlyXml -eq $false) -and ($DataType -in @('hierarchyid', 'geography')))
    {
        return "CONVERT(nvarchar(max), " + $Prefix + $ColumnName + ")"
    }

    if ($DataType -in @('xml'))
    {
        return "CONVERT(nvarchar(max), " + $Prefix + $ColumnName + ")"
    }

    if (($OnlyXml -eq $false) -and ($DataType -eq 'bit'))
    {
        return "CONVERT(char(1), $Prefix[" + $ColumnName + "])"
    }

    return "$($Prefix)[" + $ColumnName + "]"
}