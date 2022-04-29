function Truncate-Database
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Database -ConnectionInfo $ConnectionInfo
    foreach ($table in $info.Tables)
    {
        if ($table.IsHistoric -eq $true)
        {
            continue
        }
        
        if ($table.HasHistory -eq $true)
        {
            $historyTable = $info.Tables | Where-Object { ($_.IsHistoric -eq $true) -and ($_.HistoryOwner -eq $table.TableName) -and ($_.HistoryOwnerSchema -eq $table.SchemaName)}

            $sql = "ALTER TABLE " + $table.SchemaName + ".[" +  $table.TableName + "] SET ( SYSTEM_VERSIONING = OFF )"
            $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 


            $sql = "DELETE FROM " +  $table.SchemaName + "." + $table.TableName  
            $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 

            $sql = "DELETE FROM " +  $historyTable.SchemaName + "." + $historyTable.TableName  
            $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 


            $sql = "ALTER TABLE " + $table.SchemaName + ".[" +  $table.TableName + "] SET ( SYSTEM_VERSIONING = " + $historyTable.SchemaName + ".[" + $historyTable.TableName +  "] )"
            $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
        }
        else
        {
            $sql = "DELETE FROM " +  $table.SchemaName + "." + $table.TableName  
            $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }
}