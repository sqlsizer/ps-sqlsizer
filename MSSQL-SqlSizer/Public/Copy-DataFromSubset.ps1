function Copy-DataFromSubset
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Source -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $i = 0
    $subsetTables = Get-SubsetTables -Database $Source -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    foreach ($table in $subsetTables)
    {
        $i += 1

        $tableInfo = $info.Tables | Where-Object { ($_.SchemaName -eq $table.SchemaName) -and ($_.TableName -eq $table.TableName) }
        Write-Progress -Activity "Copying data" -PercentComplete (100 * ($i / ($subsetTables.Count))) -CurrentOperation "Table $($table.SchemaName).$($table.TableName)"

        if ($tableInfo.IsHistoric -eq $true)
        {
            continue
        }

        $isIdentity = $tableInfo.IsIdentity
        $schema = $tableInfo.SchemaName
        $tableName = $tableInfo.TableName
        $tableColumns = Get-TableSelect -TableInfo $tableInfo -Conversion $false -IgnoredTables $IgnoredTables -Prefix $null -AddAs $false -SkipGenerated $true
        $tableSelect = Get-TableSelect -TableInfo $tableInfo -Conversion $false -IgnoredTables $IgnoredTables -Prefix $null -AddAs $true -SkipGenerated $true

        $sql = "INSERT INTO " +  $schema + ".[" +  $tableName + "] ($tableColumns) SELECT $tableSelect FROM " + $Source + ".SqlSizerResult." + $schema + "_" + $tableName
        if ($isIdentity)
        {
            $sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON " + $sql + " SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF"
        }
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Destination -ConnectionInfo $ConnectionInfo
    }

    Write-Progress -Activity "Copying data" -Completed
}

