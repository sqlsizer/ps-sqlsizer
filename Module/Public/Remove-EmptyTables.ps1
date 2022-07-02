function Remove-EmptyTables
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Database -Connection $ConnectionInfo -MeasureSize $true
    $i = 0
    foreach ($table in $info.Tables)
    {
        Write-Progress -Activity "Removing empty tables" -PercentComplete (100 * ($i / ($info.Tables.Count)))

        if ($table.Statistics.Rows -ne 0)
        {
            continue
        }

        $shouldRemove = $true
        foreach ($fkTable in $table.IsReferencedBy)
        {
            if ($fkTable.Statistics.Rows -ne 0)
            {
                $shouldRemove = $false
                continue
            }

            foreach ($fk in $fkTable.ForeignKeys)
            {
                if (($fk.Schema -eq $table.SchemaName) -and ($fk.Table -eq $table.TableName))
                {
                    $sql = "IF OBJECT_ID('$($fkTable.SchemaName).$($fkTable.TableName)', 'U') IS NOT NULL
                            ALTER TABLE [" + $fkTable.SchemaName + "].[" + $fkTable.TableName + "] DROP CONSTRAINT IF EXISTS $($fk.Name)"
                    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
                }
            }
        }

        if ($shouldRemove)
        {
            foreach ($view in $table.Views)
            {
                $sql = "DROP VIEW IF EXISTS $view"
                Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
            }

            $sql = "DROP TABLE [$($table.SchemaName)].[$($table.TableName)]"
            Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
        $i += 1
    }

    Write-Progress -Activity "Removing empty tables" -Completed
}