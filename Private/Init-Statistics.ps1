function Init-Statistics
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    # init stats
    $sql = "INSERT INTO SqlSizer.ProcessingStats([Schema], [TableName], [ToProcess], [Processed])
            SELECT [Schema], TableName, COUNT(*), 0
            FROM [SqlSizer].[Processing]
            GROUP BY [Schema], TableName"
    $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    $info = Get-TablesInfo -Database $Database -ConnectionInfo $ConnectionInfo


    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -ne "SqlSizer")
        {
            $sql = "IF NOT EXISTS(SELECT * FROM SqlSizer.ProcessingStats WHERE [Schema] = '" + $table.SchemaName + "' and TableName = '" + $table.TableName + "') INSERT INTO SqlSizer.ProcessingStats VALUES('" +  $table.SchemaName + "', '" + $table.TableName + "', 0, 0)"
            $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }

}
