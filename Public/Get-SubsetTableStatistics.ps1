function Get-SubsetTableStatistics
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $structure = [Structure]::new($info)
    $result = @()

    foreach ($table in $info.Tables)
    {
        if ($table.PrimaryKey.Count -eq 0)
        {
            continue
        }

        $tableName = $structure.GetProcessingName($structure.Tables[$table])

        $keys = ""
        for ($i = 0; $i -lt $table.PrimaryKey.Count; $i++)
        {
            $keys += "Key$($i)"

            if ($i -lt ($table.PrimaryKey.Count - 1))
            {
                $keys += ", "
            }
        }

        $sql = "SELECT COUNT(*) as Count FROM (SELECT DISTINCT $($keys) FROM $($tableName) WHERE [Table] = $($table.Id)) x"
        $count = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

        $obj = New-Object -TypeName SubsettingTableResult
        $obj.SchemaName = $table.SchemaName
        $obj.TableName = $table.TableName
        $obj.RowCount = $count["Count"]
        $result += $obj
    }

    return $result
}