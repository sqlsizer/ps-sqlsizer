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
        $tmp = "INSERT INTO SqlSizer.Processing SELECT '" + $query.Schema + "', '" + $query.Table + "', "

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

        $tmp = $tmp + [int]$query.Color + " as Color, 0, 0, 1 FROM " + $query.Schema + "." + $query.Table + " as x WHERE " + $query.Where
        $_ = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }
}