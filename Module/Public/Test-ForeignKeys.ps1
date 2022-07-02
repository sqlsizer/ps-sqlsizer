function Test-ForeignKeys
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

    Write-Progress -Activity "Testing foreign keys" -PercentComplete 0

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $i = 0
    foreach ($table in $info.Tables)
    {
        Write-Progress -Activity "Testing foreign keys" -PercentComplete (100 * ($i / $info.Tables.Count))

        foreach ($fk in $table.ForeignKeys)
        {
            $sql = "ALTER TABLE $($table.SchemaName).$($table.TableName) WITH CHECK CHECK CONSTRAINT $($fk.Name)"
            $ok = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo -Silent $false

            if ($ok -eq $false)
            {
                Write-Output "Problem with FK $($fk.Name)"
            }
        }
        $i += 1
    }

    Write-Progress -Activity "Testing foreign keys" -Completed
}