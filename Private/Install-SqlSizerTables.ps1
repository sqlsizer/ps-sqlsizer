function Install-SqlSizerTables
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
    
    $tmp = "CREATE SCHEMA SqlSizer"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $tmp = "IF OBJECT_ID('SqlSizer.Operations') IS NOT NULL  
        Drop Table SqlSizer.Operations"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $tmp = "IF OBJECT_ID('SqlSizer.Tables') IS NOT NULL  
        Drop Table SqlSizer.Tables"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "IF OBJECT_ID('SqlSizer.ForeignKeys') IS NOT NULL  
        Drop Table SqlSizer.ForeignKeys"
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

 
    $tmp = "CREATE TABLE SqlSizer.Tables(Id int primary key identity(1,1), [Schema] varchar(64), [TableName] varchar(64))"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $sql = "CREATE NONCLUSTERED INDEX [Index] ON SqlSizer.Tables ([Schema] ASC, [TableName] ASC)"
    Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    $tmp = "CREATE TABLE SqlSizer.ForeignKeys(Id int primary key identity(1,1), [FkTableId] int, [TableId] int, [Name] varchar(256))"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        $tmp = "INSERT INTO SqlSizer.Tables VALUES('$($table.SchemaName)', '$($table.TableName)')  SELECT SCOPE_IDENTITY() as Id"
        $result = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo     
        $table.Id = $result.Id
    }

    foreach ($table in $info.Tables)
    {
        foreach ($fk in $table.ForeignKeys)
        {
            $tmp = "SELECT [Id] FROM SqlSizer.Tables WHERE [Schema] = '$($fk.FkSchema)' AND TableName = '$($fk.FkTable)'"
            $result = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

            $tmp = "SELECT [Id] FROM SqlSizer.Tables WHERE [Schema] = '$($fk.Schema)' AND TableName = '$($fk.Table)'"
            $result2 = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

            $tmp = "INSERT INTO SqlSizer.ForeignKeys VALUES($($result.Id), $($result2.Id), '$($fk.Name)') SELECT SCOPE_IDENTITY() as Id"
            $result3 = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

            $fk.Id = $result3.Id
        }
    }


    $tmp = "CREATE TABLE SqlSizer.Operations(Id int primary key identity(1,1), [Table] smallint, [Color] int, [ToProcess] int NOT NULL, [Processed] bit NOT NULL, [Source] int, [Depth] int, [Created] datetime NOT NULL)"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "CREATE NONCLUSTERED INDEX [Index] ON SqlSizer.Operations ([Table] ASC, [Color] ASC, [Source] ASC, [Depth] ASC)"
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
            $sql = "CREATE TABLE $($slice) ([Id] int primary key identity(1,1), $($columns), [Source] smallint NOT NULL, [Depth] smallint NOT NULL, [Fk] smallint)"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

            $sql = "CREATE TABLE $($processing) (Id int primary key identity(1,1), [Table] smallint NOT NULL, $($columns), [Color] tinyint NOT NULL, [Source] smallint NOT NULL, [Depth] smallint NOT NULL, [Fk] smallint)"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

            $sql = "CREATE NONCLUSTERED INDEX [Index] ON $($processing) ([Table] ASC, $($keysIndex), [Color] ASC)"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

            $sql = "CREATE NONCLUSTERED INDEX [Index_2] ON $($processing) ([Table] ASC, [Color] ASC) INCLUDE ($($keys))"
            Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }
}