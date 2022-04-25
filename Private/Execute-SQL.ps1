function Execute-SQL
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Sql,

        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

   Invoke-Sqlcmd -Query $Sql -ServerInstance $ConnectionInfo.Server -Database $Database -Username $ConnectionInfo.Login -Password $ConnectionInfo.Password -QueryTimeout 600000

   Write-Verbose $Sql
}
