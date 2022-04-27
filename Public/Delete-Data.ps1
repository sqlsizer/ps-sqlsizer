function Delete-Data
{
    
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Source -Connection $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        $isIdentity = $table.IsIdentity
        $schema = $table.SchemaName
        $tableName = $table.TableName
        
        $where = GetTableWhere -Database $Source -TableInfo $table
        $sql = "DELETE FROM " + $schema + ".[" +  $tableName + "] " + $where
        
        $_ = Execute-SQL -Sql $sql -Database $Target -ConnectionInfo $ConnectionInfo 
    }
   
}

# Function that creates a where part of query
function GetTableWhere
{
     param (
        [string]$Database,
        [TableInfo]$TableInfo
     )

     $primaryKey = $TableInfo.PrimaryKey
     $where = " WHERE EXISTS(SELECT * FROM [" + $Database + "].SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' "

     $i = 0
     foreach ($column in $primaryKey)
     {
        $where += " AND Key" + $i + " = " + $column.Name + " " 
        $i += 1
     }

     $where += ")"

     $where
}
