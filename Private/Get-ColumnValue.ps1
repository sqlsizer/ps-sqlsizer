function Get-ColumnValue
{
    param 
    (
        [string]$columnName,
        [string]$newName,
        [string]$dataType,
        [string]$prefix
    )

    $toConvert = @('hierarchyid', 'geography', 'xml')

    if ($dataType -in $toConvert)
    {
        "CONVERT(nvarchar(max), " + $prefix + $columnName + ") as [$newName]"
    }
    else 
    {
        if (($newName -ne $null) -and ($newName -ne ""))
        {
            "$($prefix)[" + $columnName + "] as [$newName]"
        }
        else
        {
            "$($prefix)[" + $columnName + "]"
        }
    }
}
