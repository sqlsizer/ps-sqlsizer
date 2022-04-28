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

        $sql = "DELETE FROM " +  $table.SchemaName + "." + $table.TableName  
        $_ = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
}