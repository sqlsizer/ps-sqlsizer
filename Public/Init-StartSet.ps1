function Init-StartSet
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
    foreach ($query in $Queries)
    {
        $top = "";
        if ($query.Top -ne 0)
        {   
            $top = " TOP " + $query.Top;
        }

        $tmp = "INSERT INTO SqlSizer.Processing SELECT " + $top  + "'" + $query.Schema + "', '" + $query.Table + "', "

        $i = 0
        foreach ($column in $query.KeyColumns)
        {
            $tmp += $column + ","
            $i += 1
        }

        for ($i; $i -lt $info.PrimaryKeyMaxSize; $i = $i + 1)
        {
           $tmp  += "NULL" + ","
        }

        $order = "";
        if ($null -ne $query.OrderBy)
        {   
            $order = " ORDER BY " + $query.OrderBy
        }
        $tmp = $tmp + [int]$query.Color + " as Color, 0, 0, 1 FROM " + $query.Schema + "." + $query.Table + " as [`$table] WHERE " + $query.Where + $order
        $null = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }
}