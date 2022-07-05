function New-DataTableClone
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$SourceDatabase,

        [Parameter(Mandatory=$true)]
        [string]$TargetDatabase,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [string]$NewSchemaName,

        [Parameter(Mandatory=$true)]
        [string]$NewTableName,

        [Parameter(Mandatory=$true)]
        [bool]$CopyData,

        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Write-Progress -Activity "Copy table $SourceDatabase.$SchemaName.$TableName" -PercentComplete 0

    $tableAlreadyExists = Test-TableExists -SchemaName $NewSchemaName -TableName $NewTableName -Database $TargetDatabase -ConnectionInfo $ConnectionInfo

    if ($tableAlreadyExists)
    {
        Write-Output "Table [$NewSchemaName].[$NewTableName] already exists in $TargetDatabase database. Provide different name"
        return
    }

    # create schema if not exist
    $schemaExists = Test-SchemaExists -SchemaName $NewSchemaName -Database $TargetDatabase -ConnectionInfo $ConnectionInfo

    if ($schemaExists -eq $false)
    {
        $sql = "CREATE SCHEMA $NewSchemaName"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $TargetDatabase -ConnectionInfo $ConnectionInfo
    }

    $tableInfo = $info.Tables | Where-Object { ($_.SchemaName -eq $SchemaName) -and ($_.TableName -eq $TableName)}
    $tableSelect = Get-TableSelect -TableInfo $tableInfo -Conversion $true -Prefix $null -AddAs $true -SkipGenerated $false -OnlyXml $true

    # copy schema
    IF ($CopyData)
    {
        $sql = "SELECT $tableSelect INTO [$TargetDatabase].[$NewSchemaName].[$NewTableName] FROM [$SchemaName].[$TableName]"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $SourceDatabase -ConnectionInfo $ConnectionInfo
    }
    else
    {
        $sql = "SELECT TOP 1 $tableSelect INTO [$TargetDatabase].[$NewSchemaName].[$NewTableName] FROM [$SchemaName].[$TableName]"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $SourceDatabase -ConnectionInfo $ConnectionInfo

        $sql = "TRUNCATE TABLE [$TargetDatabase].[$NewSchemaName].[$NewTableName]"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $SourceDatabase -ConnectionInfo $ConnectionInfo
    }

    # setup primary key and computed columns
    foreach ($table in $DatabaseInfo.Tables)
    {
        if (($table.SchemaName -eq $SchemaName) -and ($table.TableName -eq $TableName))
        {
            $sql = "ALTER TABLE [$TargetDatabase].[$NewSchemaName].[$NewTableName] ADD PRIMARY KEY ($([string]::Join(',', $table.PrimaryKey)))"
            $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

            foreach ($column in $table.Columns)
            {
                if ($column.IsComputed)
                {
                    $sql = "ALTER TABLE [$TargetDatabase].[$NewSchemaName].[$NewTableName] DROP COLUMN $($column.Name)"
                    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

                    $sql = "ALTER TABLE [$TargetDatabase].[$NewSchemaName].[$NewTableName] ADD $($column.Name) as $($column.ComputedDefinition)"
                    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
                }

                if ($column.DataType -eq 'xml')
                {
                    $sql = "ALTER TABLE [$TargetDatabase].[$NewSchemaName].[$NewTableName] ALTER COLUMN $($column.Name) xml"
                    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
                }
            }
        }
    }


    Write-Progress -Activity "Copy table $SchemaName.$TableName" -Completed
}

