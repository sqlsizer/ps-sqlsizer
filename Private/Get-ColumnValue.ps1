function Get-ColumnValue
{
    param 
    (
        [string]$columnName,
        [string]$dataType,
        [string]$prefix
    )

    if ($dataType -eq "hierarchyid")
    {
        "CONVERT(nvarchar(max), " + $prefix + $columnName + ")"
    }
    else 
    {
        if ($dataType -eq "xml")
        {
            "CONVERT(nvarchar(max), " + $prefix + $columnName + ")"
        }
        else
        {            
            
            "[" + $columnName + "]"            
        }
    }
}
