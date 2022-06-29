function New-SchemaClone
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$NewSchemaName,

        [Parameter(Mandatory=$true)]
        [bool]$CopyData,

        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    
    Write-Progress -Activity "Copy schema $SchemaName" -PercentComplete 0

    $schemaAlreadyExists = Test-SchemaExists -SchemaName $NewSchemaName -Database $Database -ConnectionInfo $ConnectionInfo

    if ($schemaAlreadyExists)
    { 
        Write-Progress -Activity "Copy schema $SchemaName" -Completed
        Write-Host "Schema $NewSchemaName already exists. Provide different name"
        return
    }
    $sql = "CREATE SCHEMA $NewSchemaName"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    
    # copy tables
    $i = 0
    foreach ($table in $DatabaseInfo.Tables)
    {
        Write-Progress -Activity "Copy schema $SchemaName" -PercentComplete (100 * ($i / ($DatabaseInfo.Tables.Count))) -CurrentOperation "Table $($table.SchemaName).$($table.TableName)"
        if ($table.SchemaName -eq $SchemaName)
        {
            New-DataTableClone -Database $Database -DatabaseInfo $DatabaseInfo -SchemaName $SchemaName -TableName $table.TableName `
                               -CopyData $CopyData -NewSchemaName $NewSchemaName -NewTableName $table.TableName -ConnectionInfo $ConnectionInfo
        }
        $i = $i + 1
    }

    # create foreign keys for new schema
    foreach ($table in $DatabaseInfo.Tables)
    {
        if ($table.SchemaName -eq $SchemaName)
        {
            foreach ($fk in $table.ForeignKeys)
            {
                $schema = $fk.Schema
                if ($schema -eq $SchemaName)
                {
                    $schema = $NewSchemaName
                }

                $sql = "ALTER TABLE $NewSchemaName.$($table.TableName) ADD CONSTRAINT $($fk.Name) FOREIGN KEY ($([string]::Join(',', $fk.FkColumns))) REFERENCES $($schema).$($fk.Table) ($([string]::Join(',', $fk.Columns)))"
                Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo -Silent $false
            }
        }
    }

    Write-Progress -Activity "Copy schema $SchemaName" -Completed
}

