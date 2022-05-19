function Initialize-Statistics
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    # init stats
    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    
    $structure = [Structure]::new($info)
    $sql = "DELETE FROM SqlSizer.Operations"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        if ($table.PrimaryKey.Length -eq 0) 
        {
            continue
        }

        $signature = $structure.Tables[$table]
        $processing = $structure.GetProcessingName($signature)

        $sql = "INSERT INTO SqlSizer.Operations([Schema], [TableName], [ToProcess], [Processed], [Color], [Depth])
        SELECT p.[Schema], p.TableName, COUNT(*), 0, p.[Color], 0
        FROM $($processing) p
        WHERE p.[Schema] = '$($table.SchemaName)' AND p.[TableName] = '$($table.TableName)'
        GROUP BY [Schema], [TableName], [Color]"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
}
