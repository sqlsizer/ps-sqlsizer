function Get-SubsetTableCsv
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

        [Parameter(Mandatory=$true)]
        [bool]$Secure,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables,

        [Parameter(Mandatory=$false)]
        [bool]$SkipHeader = $true,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $schema = "SqlSizerExport"
    if ($Secure -eq $true)
    {
        $schema = 'SqlSizerSecure'
    }

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    foreach ($table in $info.Tables)
    {
        if (($table.SchemaName -eq $SchemaName) -and ($table.TableName -eq $TableName))
        {
            $sql = "SELECT * FROM $schema.$($SchemaName)_$($TableName) FOR JSON PATH, INCLUDE_NULL_VALUES"
            $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
            $obj = ($rows | Select-Object ItemArray -ExpandProperty ItemArray) -join "" | ConvertFrom-Json
            $csv = $obj | ConvertTo-Csv  -Delimiter ';' -NoTypeInformation

            if ($SkipHeader)
            {
                $csv = $csv | select-object -skip 1
            }
            
            return [string]::Join("`r`n", $csv)
        } 
    }

    return $null
}