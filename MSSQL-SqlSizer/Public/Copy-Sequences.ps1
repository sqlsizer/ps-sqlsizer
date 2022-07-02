function Copy-Sequences
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Write-Progress -Activity "Copying sequences" -PercentComplete 0

    $sql = Get-Content -Raw -Path ($PSScriptRoot + "\..\Queries\Sequences.sql")
    $sequencesRows = Invoke-SqlcmdEx -Sql $sql -Database $Source -ConnectionInfo $ConnectionInfo

    foreach ($row in $sequencesRows)
    {
        $sql = "IF NOT EXISTS(SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('$($row["name"])') AND type = 'SO') BEGIN CREATE SEQUENCE [$($row["name"])] AS $($row["type"])  START WITH $($row["current_value"]) INCREMENT BY $($row["increment"]) MAXVALUE $($row["maximum_value"]) END"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Destination -ConnectionInfo $ConnectionInfo
    }
    Write-Progress -Activity "Copying sequences" -Completed
}