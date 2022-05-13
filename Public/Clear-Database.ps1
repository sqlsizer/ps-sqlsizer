function Clear-Database
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
    $i = 0
    foreach ($table in $info.Tables)
    {
        $i += 1
        Write-Progress -Activity "Database truncate" -PercentComplete (100 * ($i / ($info.Tables.Count)))

        if ($table.IsHistoric -eq $true)
        {
            continue
        }
        
        if ($table.HasHistory -eq $true)
        {
            $historyTable = $info.Tables | Where-Object { ($_.IsHistoric -eq $true) -and ($_.HistoryOwner -eq $table.TableName) -and ($_.HistoryOwnerSchema -eq $table.SchemaName)}

            $sql = "ALTER TABLE " + $table.SchemaName + ".[" +  $table.TableName + "] SET ( SYSTEM_VERSIONING = OFF )"
            $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 


            $sql = "DELETE FROM " +  $table.SchemaName + "." + $table.TableName  
            $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 

            $sql = "DELETE FROM " +  $historyTable.SchemaName + "." + $historyTable.TableName  
            $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 


            $sql = "ALTER TABLE " + $table.SchemaName + ".[" +  $table.TableName + "] SET ( SYSTEM_VERSIONING = ON  (HISTORY_TABLE = " + $historyTable.SchemaName + ".[" + $historyTable.TableName +  "] ))"
            $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
        }
        else
        {
            $sql = "DELETE FROM " +  $table.SchemaName + "." + $table.TableName  
            $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }

    Write-Progress -Activity "Database truncate" -Completed
}