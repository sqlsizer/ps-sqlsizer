function Get-SubsetTableJson
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

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $schema = "SqlSizerExport"
    if ($Secure -eq $true)
    {
        $schema = "SqlSizerSecure"
    }

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    foreach ($table in $info.Tables)
    {
        if (($table.SchemaName -eq $SchemaName) -and ($table.TableName -eq $TableName))
        {
            $sql = "SELECT * FROM $schema.$($SchemaName)_$($TableName) FOR JSON PATH"
            $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
            $json = ($rows | Select-Object ItemArray -ExpandProperty ItemArray) -join ""
            return $json
        }
    }

    return $null
}