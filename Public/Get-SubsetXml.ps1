function Get-SubsetXml
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,
        
        [Parameter(Mandatory=$false)]
        [bool]$AllColumns = $false,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Write-Progress -Activity "Exploring to XML" -PercentComplete 0 
    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $subsetTables = Get-SubsetTables -Database $Database -ConnectionInfo $ConnectionInfo -DatabaseInfo $info
    $result = @()

    $index = 0
    foreach ($subsetTable in $subsetTables)
    {
        Write-Progress -Activity "Exploring to XML" -PercentComplete (100 * ($index / $subsetTables.Count))

        $subsetTableRows = Get-SubsetTableRows -AllColumns $AllColumns -SchemaName $subsetTable.SchemaName -TableName $subsetTable.TableName -Database $Database -ConnectionInfo $ConnectionInfo  -DatabaseInfo $info
        $rows = @()

        foreach ($subsetTableRow in $subsetTableRows)
        {
            $row = New-Object TableInfo2Row
            $i = 0
            foreach ($item in $subsetTableRow.ItemArray)
            {
                if (($AllColumns -eq $false) -or ($i -gt 1))
                {
                    $column = New-Object TableInfo2Column
                    $column.Value = $item
                    $column.Name = $subsetTableRow.Table.Columns[$i]
                    $row.Columns += $column
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