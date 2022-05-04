function Get-SubsetProgress
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $sql = "SELECT ISNULL(SUM(ToProcess), 0) as to_process, ISNULL(SUM(Processed), 0) as processed FROM SqlSizer.ProcessingStats"
    $row = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    $result = New-Object -TypeName SubsettingProcess
    $result.ToProcess = $row["to_process"]
    $result.Processed = $row["processed"]

    return $result
}