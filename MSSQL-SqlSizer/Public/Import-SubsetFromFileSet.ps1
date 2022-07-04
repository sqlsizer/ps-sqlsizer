function Import-SubsetFromFileSet
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$SourceDatabase,

        [Parameter(Mandatory=$true)]
        [string]$TargetDatabase,

        [Parameter(Mandatory=$true)]
        [TableFile[]]$Files,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    
    foreach ($file in $Files)
    {
        $tableInfo = $info.Tables | Where-Object { ($_.SchemaName -eq $file.TableContent.SchemaName) -and ($_.TableName -eq $file.TableContent.TableName) }

        $tableSelect = Get-TableSelect -TableInfo $tableInfo -Conversion $false -IgnoredTables $IgnoredTables -Prefix $null -AddAs $false -SkipGenerated $true
        $columns = @()
        foreach ($column in $tableInfo.Columns)
        {
            if ($column.DataType -in @('geography', 'hierarchyid'))
            {
                $type = 'varchar(max)'
            }
            else
            {
                $type = $column.DataType
                
                if ($type -in @('nvarchar', 'varchar'))
                {
                    $type += "(max)"
                }
            }

            $columns += "[" + $column.Name + "] " + $type
        }

        $identity_on = ""
        $identity_off = ""

        if ($tableInfo.IsIdentity)
        {
            $identity_on = "SET IDENTITY_INSERT " + $TargetDatabase + "." + $tableInfo.SchemaName + ".[" + $tableInfo.TableName + "] ON "
            $identity_off = "SET IDENTITY_INSERT " + $TargetDatabase + "." + $tableInfo.SchemaName + ".[" + $tableInfo.TableName + "] OFF "
        }

        $sql = "DECLARE @json NVARCHAR(MAX); SELECT @json = STRING_AGG([Content], '') FROM $SourceDatabase.SqlSizer.Files WHERE [FileId] = '$($file.FileId)'
                $identity_on

                INSERT INTO $TargetDatabase.[$($tableInfo.SchemaName)].[$($tableInfo.TableName)] ($tableSelect)
                SELECT $tableSelect 
                FROM OpenJson(@json) with ($([string]::join(', ', $columns)))
                
                $identity_off"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
}