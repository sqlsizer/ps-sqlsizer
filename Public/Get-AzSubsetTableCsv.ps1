function Get-AzSubsetTableCsv
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    foreach ($table in $info.Tables)
    {
        if (($table.SchemaName -eq $SchemaName) -and ($table.TableName -eq $TableName))
        {
            $select = Get-TableSelect -TableInfo $table -Raw $true -IgnoredTables $IgnoredTables -Prefix $null -ConvertBits $true
            $sql = "SELECT $select FROM SqlSizerResult.$($SchemaName)_$($TableName) FOR JSON PATH, INCLUDE_NULL_VALUES"
            $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
            $obj = ($rows | Select-Object ItemArray -ExpandProperty ItemArray) -join "" | ConvertFrom-Json
            $csv = $obj | ConvertTo-Csv  -Delimiter ';' -NoTypeInformation | select-object -skip 1
            
            return $csv
        }
    }

    return $null
}