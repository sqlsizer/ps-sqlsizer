function Get-ColumnValue
{
    param 
    (
        [string]$columnName,
        [string]$dataType,
        [string]$prefix
    )

    $toConvert = @('hierarchyid', 'geography', 'xml')

    if ($dataType -in $toConvert)
    {
        "CONVERT(nvarchar(max), " + $prefix + $columnName + ")"
    }
    else 
    {
        "$($prefix)[" + $columnName + "]"
    }
}
