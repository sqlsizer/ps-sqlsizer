function Invoke-SqlcmdEx
{
    [cmdletbinding()]
    [outputtype([System.Boolean])]
    [outputtype([System.Object])]
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

        if (($null -ne $ConnectionInfo.AccessToken) -and ($ConnectionInfo.AccessToken -ne ""))
        {
            $params.AccessToken = $ConnectionInfo.AccessToken
        }

        if ($null -ne $ConnectionInfo.Credential)
        {
            $params.Credential = $ConnectionInfo.Credential
        }

        if ($true -eq $Statistics)
        {
            $params.Query = 'SET STATISTICS IO ON
            ' + $Sql + '
            SET STATISTICS IO OFF'

            $verbose = ForEach-Object { $result = Invoke-Sqlcmd @params -ErrorAction Stop } 4>&1
            $message = $verbose.Message
            $logicalReads = Get-LogicalReadsValue -Message $message
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
            Write-Output "Exception message: $($_.Exception.Message)"
            Write-Output "Error: " $_.Exception
            Write-Output $Sql
            Write-Output "=="
        }
        return $false
    }
}
