function Test-DatabaseOnline    
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,
        
        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $sql = "SELECT state_desc FROM sys.databases where [name] = '$Database'"
    $result = Execute-SQL -Sql $sql -Database 'master' -ConnectionInfo $ConnectionInfo

    if ($null -eq $result)
    {
        return $false
    }

    if ($result['state_desc'] -eq 'ONLINE')
    {
        return $true
    }   
    else
    {
        return $false
    }
}