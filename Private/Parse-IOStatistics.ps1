function Parse-IOStatistics
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]]$Message
    )

    if ($null -eq $Message)
    {
        return 0
    }

    $result = 0

    foreach ($row in $Message)
    {
        $position = $row.IndexOf('logical reads');
        $start = $position + 14
        $end = $row.IndexOf(',', $start)

        $logicalReads = $row.Substring($start, $end - $start) -as [int]
        $result += $logicalReads
    }

    return $result
}