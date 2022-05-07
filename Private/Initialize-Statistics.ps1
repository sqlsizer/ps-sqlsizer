function Initialize-Statistics
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
    $info = Get-DatabaseInfo -Database $Database -Connection $ConnectionInfo
    $structure = [Structure]::new($info)
    $sql = "DELETE FROM SqlSizer.ProcessingStats"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    
    foreach ($signature in $structure.Signatures.Keys)
    {
        $processing = $structure.GetProcessingName($signature)
        
        $sql = "INSERT INTO SqlSizer.ProcessingStats([Schema], [TableName], [ToProcess], [Processed], [Type])
                SELECT p.[Schema], p.TableName, COUNT(*), 0, p.[Type]
                FROM $($processing) p
                GROUP BY [Schema], TableName, [Type]"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -ne "SqlSizer")
        {
            for ($i = 1; $i -lt 5; $i++)
            {
                $sql = "IF NOT EXISTS(SELECT * FROM SqlSizer.ProcessingStats WHERE [Schema] = '" + $table.SchemaName + "' and TableName = '" + $table.TableName + "' and [Type] = $($i)) INSERT INTO SqlSizer.ProcessingStats VALUES('" +  $table.SchemaName + "', '" + $table.TableName + "', 0, 0, $($i))"
                $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
            }
        }
    }
}
