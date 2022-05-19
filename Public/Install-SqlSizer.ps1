function Install-SqlSizer
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $tmp = "IF OBJECT_ID('SqlSizer.Operations') IS NOT NULL  
        Drop Table SqlSizer.Operations"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $structure = [Structure]::new($info)
    foreach ($signature in $structure.Signatures.Keys)
    {
        $slice = $structure.GetSliceName($signature)
        $tmp = "IF OBJECT_ID('$($slice)') IS NOT NULL  
            Drop Table $($slice)"
        Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }

    foreach ($signature in $structure.Signatures.Keys)
    {
        $processing = $structure.GetProcessingName($signature)
        $tmp = "IF OBJECT_ID('$($processing)') IS NOT NULL  
            Drop Table $($processing)"
        Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $tmp = "DROP SCHEMA IF EXISTS SqlSizer"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "CREATE SCHEMA SqlSizer"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $tmp = "CREATE TABLE SqlSizer.Operations(Id int primary key identity(1,1), [Schema] varchar(64), [TableName] varchar(64), [Color] int, [ToProcess] int NOT NULL, [Processed] bit NOT NULL, [Source] int, [Depth] int)"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "CREATE NONCLUSTERED INDEX [Index] ON SqlSizer.Operations ([Schema] ASC, [TableName] ASC, [Color] ASC, [Source] ASC, [Depth] ASC)"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    foreach ($signature in $structure.Signatures.Keys)
    {
        $slice = $structure.GetSliceName($signature)
        $processing = $structure.GetProcessingName($signature)

        $keys = ""
        $columns = ""
        $keysIndex = ""
        $i = 0
        $len = $structure.Signatures[$signature].Count

        foreach ($column in $structure.Signatures[$signature])
        {
            $keys += " Key$($i) "
            $columns += " Key$($i) "
            $keysIndex += " Key$($i) ASC "

            if ($column.DataType -in @('varchar', 'nvarchar', 'char', 'nchar'))
            {
                $columns += $column.DataType + "(" + $column.Length + ") NOT NULL "
            }
            else
            {
                $columns += $column.DataType + " NOT NULL "
            }

            if ($i -lt ($len - 1))
            {
                $keysIndex += ", "
                $keys += ", "
                $columns += ", "
            }

            $i += 1
        }

        if ($len -gt 0)
        {
            $sql = "CREATE TABLE $($slice) ([Id] int primary key identity(1,1), $($columns), [Source] smallint NOT NULL, [Depth] smallint NOT NULL)"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

            $sql = "CREATE UNIQUE NONCLUSTERED INDEX [Index] ON $($slice) ($($keysIndex), [Source] ASC)"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

            $sql = "CREATE TABLE $($processing) (Id int primary key identity(1,1), [Schema] varchar(64) NOT NULL, [TableName] varchar(64) NOT NULL, $($columns), [Color] tinyint NOT NULL, [Source] smallint NOT NULL, [Depth] smallint NOT NULL)"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

            $sql = "CREATE NONCLUSTERED INDEX [Index] ON $($processing) ([Schema] ASC, TableName ASC, $($keysIndex), [Color] ASC)"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }
}