function Get-AzSubsetTableJson
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
            $select = Get-TableSelect -TableInfo $table -Raw $true -IgnoredTables $IgnoredTables -Prefix $null
            $sql = "SELECT $select FROM SqlSizerResult.$($SchemaName)_$($TableName) FOR JSON PATH"
            $rows = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
            $json = ($rows | Select-Object ItemArray -ExpandProperty ItemArray) -join ""
            return $json
        }
    }

    return $null
}