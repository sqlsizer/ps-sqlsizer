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

    $result = New-Object -TypeName SubsettingProcess

    $sql = "SELECT ISNULL(SUM(ToProcess), 0) as to_process FROM SqlSizer.Operations WHERE Processed = 0"
    $row = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $result.ToProcess = $row["to_process"]

    $sql = "SELECT ISNULL(SUM(ToProcess), 0) as processed FROM SqlSizer.Operations WHERE Processed = 1"
    $row = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $result.Processed = $row["processed"]

    return $result
}