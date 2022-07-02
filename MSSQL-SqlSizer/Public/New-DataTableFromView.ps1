function New-DataTableFromView
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$NewSchemaName,

        [Parameter(Mandatory=$true)]
        [string]$NewTableName,

        [Parameter(Mandatory=$true)]
        [string]$ViewSchemaName,

        [Parameter(Mandatory=$true)]
        [string]$ViewName,

        [Parameter(Mandatory=$true)]
        [bool]$CopyData,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    Write-Progress -Activity "Copy view $ViewSchemaName.$ViewName" -PercentComplete 0

    $tableAlreadyExists = Test-TableExists -SchemaName $NewSchemaName -TableName $NewTableName -Database $Database -ConnectionInfo $ConnectionInfo

    if ($tableAlreadyExists)
    {
        Write-Progress -Activity "Copy view $ViewSchemaName.$ViewName" -Completed
        Write-Output "Table [$NewSchemaName].[$NewTableName] already exists. Provide different name"
        return
    }

    # create schema if not exist
    $schemaExists = Test-SchemaExists -SchemaName $NewSchemaName -Database $Database -ConnectionInfo $ConnectionInfo

    if ($schemaExists -eq $false)
    {
        $sql = "CREATE SCHEMA $NewSchemaName"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    # copy schema
    IF ($CopyData)
    {
        $sql = "SELECT * INTO [$NewSchemaName].[$NewTableName] FROM [$ViewSchemaName].[$ViewName]"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
    else
    {
        $sql = "SELECT TOP 1 * INTO [$NewSchemaName].[$NewTableName] FROM [$ViewSchemaName].[$ViewName]"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

        $sql = "TRUNCATE TABLE [$NewSchemaName].[$NewTableName]"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    Write-Progress -Activity "Copy view $ViewSchemaName.$ViewName" -Completed
}