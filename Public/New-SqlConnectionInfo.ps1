function New-SqlConnectionInfo
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Server,
        [string]$Login,
        [string]$Password
    )

    return [SqlConnectionInfo]@{
        Server = $Server
        Login =  $Login
        Password = $Password
        Statistics = New-Object -Type SqlConnectionStatistics
    }
}
