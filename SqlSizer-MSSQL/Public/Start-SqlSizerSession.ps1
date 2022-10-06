function Start-SqlSizerSession
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Database,

        [Parameter(Mandatory = $true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory = $true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    $sessionId = (New-Guid).ToString().Replace("-", "_")

    Write-Host "SqlSizer: Starting new session: $sessionId"

    Write-Host "SqlSizer: Installation verification"
    
    # install sql sizer if not installed
    Install-SqlSizer -Database $Database -ConnectionInfo $ConnectionInfo -DatabaseInfo $DatabaseInfo -SessionId $sessionId

    # save session id
    $sql = "INSERT INTO SqlSizer.Sessions(SessionId) VALUES('$SessionId')"
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    Write-Host "SqlSizer: Installation of session views and tables"
    # install session structures
    Install-SqlSizerSessionTables -SessionId $sessionId -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
    Install-SqlSizerResultViews -SessionId $sessionId -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
    Install-SqlSizerSecureViews -SessionId $sessionId -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
    Install-SqlSizerExportViews -SessionId $sessionId -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo

    Update-DatabaseInfo -DatabaseInfo $DatabaseInfo -Database $Database -ConnectionInfo $ConnectionInfo -MeasureSize ($DatabaseInfo.DatabaseSize -ne "")

    return $sessionId
}