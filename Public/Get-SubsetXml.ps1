function Get-SubsetXml
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Write-Progress -Activity "Exploring to XML" -PercentComplete 0 

    $subsetTables = Get-SubsetTables -Database $Database -ConnectionInfo $ConnectionInfo
    $result = @()

    $index = 0
    foreach ($subsetTable in $subsetTables)
    {
        Write-Progress -Activity "Exploring to XML" -PercentComplete (100 * ($index / $subsetTables.Count))

        $subsetTableRows = Get-SubsetTableRows -AllColumns $true -SchemaName $subsetTable.SchemaName -TableName $subsetTable.TableName -Database $Database -ConnectionInfo $ConnectionInfo 
        $rows = @()

        foreach ($subsetTableRow in $subsetTableRows)
        {
            $row = New-Object TableInfo2Row
            $i = 0
            foreach ($item in $subsetTableRow.ItemArray)
            {
                if ($i -gt 1)
                {
                    $row.Columns += $item
                }
                $i += 1
            }
            $rows += $row
        }

        $objectToSerialize = New-Object TableInfo2WithRows -Property @{
            SchemaName = $subsetTable.SchemaName
            TableName = $subsetTable.TableName
            Rows = $rows
        }

        $result += $objectToSerialize
        $index += 1
    }

    $tableXml = ConvertTo-Xml -InputObject $result -Depth 32
    
    Write-Progress -Activity "Exploring to XML" -PercentComplete 100

    return $tableXml.OuterXml
}