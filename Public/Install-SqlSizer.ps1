function Install-SqlSizer
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Uninstall-SqlSizer -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo

    Install-SqlSizerTables -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
    Install-SqlSizerResultViews -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
    Install-SqlSizerSecureViews -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
    Install-SqlSizerExportViews -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
}