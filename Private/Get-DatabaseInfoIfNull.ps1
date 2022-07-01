function Get-DatabaseInfoIfNull
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    if ($null -ne $DatabaseInfo)
    {
        $info = $DatabaseInfo
    }
    else
    {
        $info = Get-DatabaseInfo -Database $Database -ConnectionInfo $ConnectionInfo
    }

    return $info
}