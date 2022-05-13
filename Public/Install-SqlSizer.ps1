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

    $tmp = "IF OBJECT_ID('SqlSizer.ProcessingStats') IS NOT NULL  
        Drop Table SqlSizer.ProcessingStats"
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

    $tmp = "CREATE TABLE SqlSizer.ProcessingStats (Id int primary key identity(1,1), [Schema] varchar(64), TableName varchar(64), ToProcess int, Processed int, [Type] int)"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    foreach ($signature in $structure.Signatures.Keys)
    {
        $slice = $structure.GetSliceName($signature)
        $processing = $structure.GetProcessingName($signature)

        $keys = ""
        $keysIndex = ""
        $i = 0
        foreach ($column in $structure.Signatures[$signature])
        {
            $keys += "Key$($i) "
            $keysIndex += "Key$($i) ASC, "

            if ($column.DataType -in @('varchar', 'nvarchar', 'char', 'nchar'))
            {
                $keys += $column.DataType + "(" + $column.Length + ") NOT NULL, "
            }
            else
            {
                $keys += $column.DataType + " NOT NULL,"
            }
            $i += 1
        }

        $sql = "CREATE TABLE $($slice) (Id int primary key identity(1,1), $($keys) Depth int NULL)"
        Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

        $sql = "CREATE UNIQUE INDEX [Index] ON $($slice) ($($keysIndex) [Depth] ASC)"
        Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

        $sql = "CREATE TABLE $($processing) (Id int primary key identity(1,1), [Schema] varchar(64) NOT NULL, TableName varchar(64) NOT NULL, $($keys) [type] INT NOT NULL, [status] INT NOT NULL, [depth] INT NOT NULL, [initial] bit NULL)"
        Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

        $sql = "CREATE UNIQUE INDEX [Index] ON $($processing) ([Schema] ASC, TableName ASC, $($keysIndex) [Type] ASC, [Depth] ASC)"
        Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
}