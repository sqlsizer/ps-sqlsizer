function New-DataTableClone
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
    
    Write-Progress -Activity "Copy table $SchemaName.$TableName" -PercentComplete 0

    $tableAlreadyExists = Test-TableExists -SchemaName $NewSchemaName -TableName $NewTableName -Database $Database -ConnectionInfo $ConnectionInfo

    if ($tableAlreadyExists)
    {
        Write-Host "Table [$NewSchemaName].[$NewTableName] already exists. Provide different name"
        return
    }

    # create schema if not exist
    $schemaExists = Test-SchemaExists -SchemaName $NewSchemaName -Database $Database -ConnectionInfo $ConnectionInfo

    if ($schemaExists -eq $false)
    {
        $sql = "CREATE SCHEMA $NewSchemaName"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    # copy schema
    IF ($CopyData)
    {
        $sql = "SELECT * INTO [$NewSchemaName].[$NewTableName] FROM [$SchemaName].[$TableName]"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
    else
    {
        $sql = "SELECT TOP 1 * INTO [$NewSchemaName].[$NewTableName] FROM [$SchemaName].[$TableName]"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

        $sql = "TRUNCATE TABLE [$NewSchemaName].[$NewTableName]"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    # setup primary key
    foreach ($table in $DatabaseInfo.Tables)
    {
        if (($table.SchemaName -eq $SchemaName) -and ($table.TableName -eq $TableName))
        {
            $sql = "ALTER TABLE [$NewSchemaName].[$NewTableName] ADD PRIMARY KEY ($([string]::Join(',', $table.PrimaryKey)))"
            $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
        }
    }


    Write-Progress -Activity "Copy table $SchemaName.$TableName" -Completed
}

