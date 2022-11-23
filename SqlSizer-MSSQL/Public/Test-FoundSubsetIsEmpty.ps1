function Test-FoundSubsetIsEmpty
{
    [cmdletbinding()]
    [outputtype([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Database,

        [Parameter(Mandatory = $true)]
        [string]$SessionId,

        [Parameter(Mandatory = $true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory = $true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $result = Get-SubsetTableStatistics -SessionId $SessionId -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo

    $sum = 0

    foreach ($item in $result)
    {
        $sum += $item.RowCount
    }

    return ($sum -eq 0)
}
