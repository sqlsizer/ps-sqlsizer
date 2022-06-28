function Copy-Data
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
    foreach ($table in $info.Tables)
    {
        $i += 1
        Write-Progress -Activity "Copying data" -PercentComplete (100 * ($i / ($info.Tables.Count))) -CurrentOperation "Table $($table.SchemaName).$($table.TableName)"

        if ($table.IsHistoric -eq $true)
        {
            continue
        }

        $isIdentity = $table.IsIdentity
        $schema = $table.SchemaName
        $tableName = $table.TableName
        $tableColumns = Get-TableSelect -TableInfo $table -Raw $true -IgnoredTables $IgnoredTables -Prefix $null -AddAs $false -ConvertBit $false
        $tableSelect = Get-TableSelect -TableInfo $table -Raw $false -IgnoredTables $IgnoredTables -Prefix $null -AddAs $true -ConvertBit $true

        $sql = "INSERT INTO " +  $schema + ".[" +  $tableName + "] ($tableColumns) SELECT $tableSelect FROM " + $Source + ".SqlSizerResult." + $schema + "_" + $tableName
        if ($isIdentity)
        {
            $sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON " + $sql + " SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF" 
        }
        $null = Execute-SQL -Sql $sql -Database $Destination -ConnectionInfo $ConnectionInfo 
    }
    
    Write-Progress -Activity "Copying data" -Completed
}

