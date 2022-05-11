function Initialize-StartSet
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [Query[]]$Queries,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Database -ConnectionInfo $ConnectionInfo
    $structure = [Structure]::new($info)

    foreach ($query in $Queries)
    {
        $top = "";
        if ($query.Top -ne 0)
        {   
            $top = " TOP " + $query.Top;
        }
        $table = $info.Tables | Where-Object {($_.SchemaName -eq $query.Schema) -and ($_.TableName -eq $query.Table)}
        $procesing = $Structure.GetProcessingName($structure.Tables[$table])
        $tmp = "INSERT INTO $($procesing) SELECT " + $top  + "'" + $query.Schema + "', '" + $query.Table + "', "

        $i = 0
        foreach ($column in $query.KeyColumns)
        {
            $tmp += $column + ","
            $i += 1
        }

        $order = "";
        if ($null -ne $query.OrderBy)
        {   
            $order = " ORDER BY " + $query.OrderBy
        }
        $tmp = $tmp + [int]$query.Color + " as Color, 0, 0, 1 FROM " + $query.Schema + "." + $query.Table + " as [`$table] " 

        if ($null -ne $query.Where)
        {
            $tmp += " WHERE " + $query.Where 
        }

        $tmp += " " + $order

        $null = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }
}