function Execute-SQL
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Sql,

        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [string]$Silent = $false,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo,

        [Parameter(Mandatory=$false)]
        [bool]$Statistics = $false
    )
    
    try
    {
        $params = @{
            Query = $Sql
            ServerInstance = $ConnectionInfo.Server
            Database = $Database
            QueryTimeout = 6000
            Verbose = $true
            EncryptConnection = $ConnectionInfo.EncryptConnection
        }

        if (($ConnectionInfo.AccessToken -ne $null) -and ($ConnectionInfo.AccessToken -ne ""))
        {
            $params.AccessToken = $ConnectionInfo.AccessToken
        }

        if ($ConnectionInfo.Credential -ne $null)
        {
            $params.Credential = $ConnectionInfo.Credential
        }

        if ($true -eq $Statistics)
        {
            $params.Query = 'SET STATISTICS IO ON 
            ' + $Sql + '
            SET STATISTICS IO OFF'

            $verbose = %{ $result = Invoke-Sqlcmd @params -ErrorAction Stop } 4>&1
            $message = $verbose.Message
            $logicalReads = Parse-IOStatistics -Message $message
            $ConnectionInfo.Statistics.LogicalReads += $logicalReads
            return $result
        }
        else
        {
            Invoke-Sqlcmd @params -ErrorAction Stop 
        }
        
        Write-Verbose $Sql
    }
    catch
    {
        if ($Silent -eq $false)
        {
            Write-Host "Exception message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Error: " $_.Exception -ForegroundColor Red            
            Write-Host $Sql
            Write-Host "=="
        }
        return $false
    }
}
