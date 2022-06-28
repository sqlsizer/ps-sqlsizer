function Test-TableExists
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    
    # create schema if not exist
    $sql = "SELECT OBJECT_ID(N'$SchemaName.$TableName', N'U') as Id"
    $results = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    if (($results -ne $null) -and ("" -ne $results.Id))
    {
        return $true
    }
    
    return $false
}