function Init-Structures
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $tmp = "IF OBJECT_ID('SqlSizer.Slice') IS NOT NULL  
        Drop Table SqlSizer.Slice"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "IF OBJECT_ID('SqlSizer.ProcessingStats') IS NOT NULL  
        Drop Table SqlSizer.ProcessingStats"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "IF OBJECT_ID('SqlSizer.Processing') IS NOT NULL
        Drop Table SqlSizer.Processing"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "DROP SCHEMA IF EXISTS SqlSizer"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "CREATE SCHEMA SqlSizer"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $tmp = "CREATE TABLE SqlSizer.ProcessingStats (Id int primary key identity(1,1), [Schema] varchar(64), TableName varchar(64), ToProcess int, Processed int)"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = GetCreateSliceTableQuery -DatabaseInfo $DatabaseInfo
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
     
    $tmp = GetCreateSliceTableIndexQuery -DatabaseInfo $DatabaseInfo
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = GetCreateProcessingTableQuery -DatabaseInfo $DatabaseInfo
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
   
    $tmp = GetCreateProcessingTableIndexQuery -DatabaseInfo $DatabaseInfo
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    
    $tmp = "TRUNCATE TABLE SqlSizer.Processing"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
}

 

function GetCreateProcessingTableQuery
{
    param
    (   
        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo
    )

    $i = 0
    $keys = ""
    for ($i; $i -lt $DatabaseInfo.PrimaryKeyMaxSize; $i++)
    {
        $keys = $keys + "Key" + $i + " varchar(32),"
    }

    $sql = "CREATE TABLE SqlSizer.Processing (Id int primary key identity(1,1), [Schema] varchar(64), TableName varchar(64), " + $keys + " [type] int, [status] int, [depth] int, [initial] bit NULL)"

    $sql
}

function GetCreateProcessingTableIndexQuery
{
    param
    (   
        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo
    )

    $i = 0
    $keys = ""
    for ($i; $i -lt $DatabaseInfo.PrimaryKeyMaxSize; $i++)
    {
        $keys = $keys + "Key" + $i + " ASC,"
    }

    $sql = "CREATE UNIQUE INDEX [Index] ON SqlSizer.[Processing] ([Schema] ASC, TableName ASC, " + $keys + " [type] ASC)"

    $sql
}

function GetCreateSliceTableQuery
{
    param
    (   
        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo
    )

    $i = 0
    $keys = ""
    for ($i; $i -lt $DatabaseInfo.PrimaryKeyMaxSize; $i++)
    {
        $keys = $keys + "Key" + $i + " varchar(32),"
    }

    $sql = "CREATE TABLE SqlSizer.Slice (Id int primary key identity(1,1), " + $keys +  " Depth int NULL)"

    $sql
}


function GetCreateSliceTableIndexQuery
{
    param
    (   
        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo
    )

    $i = 0
    $keys = ""
    for ($i; $i -lt $DatabaseInfo.PrimaryKeyMaxSize; $i++)
    {
        $keys = $keys + "Key" + $i + " ASC,"
    }

    $sql = "CREATE UNIQUE INDEX [Index] ON SqlSizer.Slice (" + $keys +  " [Depth] ASC)"

    $sql
}