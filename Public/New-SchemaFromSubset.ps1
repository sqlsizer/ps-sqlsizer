function New-SchemaFromSubset
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$NewSchemaSuffix,

        [Parameter(Mandatory=$true)]
        [bool]$CopyData,

        [Parameter(Mandatory=$true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    
    $subsetTables = Get-SubsetTables -Database $Database -ConnectionInfo $ConnectionInfo -DatabaseInfo $DatabaseInfo

    # create tables
    foreach ($subsetTable in $subsetTables)
    {
        New-DataTableFromSubsetTable -Database $Database -NewSchemaName "$($subsetTable.SchemaName)_$NewSchemaSuffix" -NewTableName "$($subsetTable.TableName)" `
                     -SchemaName $subsetTable.SchemaName -TableName $subsetTable.TableName -CopyData $CopyData -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo
    }

    # create foreign keys
    foreach ($table in $DatabaseInfo.Tables)
    {
         $isSubsetTable = $subsetTables | Where-Object { ($_.SchemaName -eq $table.SchemaName) -and ($_.TableName -eq $table.TableName)}

         if ($null -ne $isSubsetTable)
         {
             foreach ($fk in $table.ForeignKeys)
             {
                 $sql = "ALTER TABLE $($table.SchemaName)_$NewSchemaSuffix.$($table.TableName) ADD CONSTRAINT $($fk.Name) FOREIGN KEY ($([string]::Join(',', $fk.FkColumns))) REFERENCES $($fk.Schema)_$NewSchemaSuffix.$($fk.Table) ($([string]::Join(',', $fk.Columns)))"
                 Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo -Silent $false
             }
         }
     } 
}