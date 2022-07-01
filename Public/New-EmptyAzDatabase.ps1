function New-EmptyAzDatabase
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$NewDatabase,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    # Copy db
    Copy-AzDatabase -Database $Database -NewDatabase $NewDatabase -ConnectionInfo $ConnectionInfo

    # Wait for a copy
    do
    {
        $found = Test-DatabaseOnline -Database $NewDatabase -ConnectionInfo $ConnectionInfo
        Start-Sleep -Seconds 5
    }
    while ($found -eq $false)

    # Clear copy
    Disable-IntegrityChecks -Database $NewDatabase -ConnectionInfo $ConnectionInfo -DatabaseInfo $info
    Clear-Database -Database $NewDatabase -ConnectionInfo $ConnectionInfo -DatabaseInfo $info
    Uninstall-SqlSizer -Database $NewDatabase -ConnectionInfo $ConnectionInfo
    Enable-IntegrityChecks -Database $NewDatabase -ConnectionInfo $ConnectionInfo -DatabaseInfo $info
    Format-Indexes -Database $NewDatabase -ConnectionInfo $ConnectionInfo
    Compress-Database -Database $NewDatabase -ConnectionInfo $ConnectionInfo
}