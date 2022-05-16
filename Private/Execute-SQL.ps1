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
        [SqlConnectionInfo]$ConnectionInfo

    )
    
    try
    {
        Invoke-Sqlcmd -Query $Sql -ServerInstance $ConnectionInfo.Server -Database $Database -Username $ConnectionInfo.Login -Password $ConnectionInfo.Password -QueryTimeout 6000 -ErrorAction Stop 
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
