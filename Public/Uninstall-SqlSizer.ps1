function Uninstall-SqlSizer
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $tmp = "IF OBJECT_ID('SqlSizer.Operations') IS NOT NULL  
        Drop Table SqlSizer.Operations"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $tmp = "IF OBJECT_ID('SqlSizer.Tables') IS NOT NULL  
        Drop Table SqlSizer.Tables"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $tmp = "IF OBJECT_ID('SqlSizer.ForeignKeys') IS NOT NULL  
        Drop Table SqlSizer.ForeignKeys"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $structure = [Structure]::new($info)

    foreach ($signature in $structure.Signatures.Keys)
    {
        $slice = $structure.GetSliceName($signature)
        $tmp = "IF OBJECT_ID('$($slice)') IS NOT NULL  
            Drop Table $($slice)"
        Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }

    foreach ($signature in $structure.Signatures.Keys)
    {
        $processing = $structure.GetProcessingName($signature)
        $tmp = "IF OBJECT_ID('$($processing)') IS NOT NULL  
            Drop Table $($processing)"
        Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }

    foreach ($table in $info.Tables)
    {
        $tmp = "IF OBJECT_ID('SqlSizerResult.$($table.SchemaName)_$($table.TableName)', 'V') IS NOT NULL  
        DROP VIEW SqlSizerResult.$($table.SchemaName)_$($table.TableName)"
        Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $tmp = "DROP SCHEMA IF EXISTS SqlSizer"
    $null = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $tmp = "DROP SCHEMA IF EXISTS SqlSizerResult"
    $null = Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
}