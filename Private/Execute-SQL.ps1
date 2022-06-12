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
        if ($true -eq $Statistics)
        {
            $Sql = 'SET STATISTICS IO ON 
            ' + $Sql + '
            SET STATISTICS IO OFF'

            $verbose = %{ $result = Invoke-Sqlcmd -Query $Sql -ServerInstance $ConnectionInfo.Server -Verbose -Database $Database -Username $ConnectionInfo.Login -Password $ConnectionInfo.Password -QueryTimeout 6000 -ErrorAction Stop } 4>&1
            $message = $verbose.Message
            $logicalReads = Parse-IOStatistics -Message $message
            $ConnectionInfo.Statistics.LogicalReads += $logicalReads
            return $result
        }
        else
        {
            Invoke-Sqlcmd -Query $Sql -ServerInstance $ConnectionInfo.Server -Database $Database -Username $ConnectionInfo.Login -Password $ConnectionInfo.Password -QueryTimeout 6000 -ErrorAction Stop 
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
