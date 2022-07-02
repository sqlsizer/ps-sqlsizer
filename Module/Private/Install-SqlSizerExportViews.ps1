function Install-SqlSizerExportViews
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables
    )

    $tmp = "CREATE SCHEMA SqlSizerExport"
    Invoke-SqlcmdEx -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $structure = [Structure]::new($info)

    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -in @('SqlSizer'))
        {
            continue
        }
        $tableSelect = Get-TableSelect -TableInfo $table -Conversion $true -IgnoredTables $IgnoredTables -Prefix "t." -AddAs $true -SkipGenerated $true
        $join = GetTableJoin -TableInfo $table -Structure $structure

        if ($null -eq $join)
        {
            continue
        }

        $sql = "CREATE VIEW SqlSizerExport.$($table.SchemaName)_$($table.TableName) AS SELECT $tableSelect from $($table.SchemaName).$($table.TableName) t INNER JOIN $join"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }
}

function GetTableJoin
{
     param (
        [TableInfo]$TableInfo,
        [Structure]$Structure
     )

     $primaryKey = $TableInfo.PrimaryKey
     $signature = $Structure.Tables[$TableInfo]

     if (($null -eq $signature) -or ($signature -eq ""))
     {
        return $null
     }

     $processing = $Structure.GetProcessingName($signature)
     $select = @()
     $join = @()

     $i = 0
     foreach ($column in $primaryKey)
     {
        $select += "p.Key$i"
        $join += "t.$column = rr.Key$i"
        $i = $i + 1
     }

     $sql = " (SELECT DISTINCT $([string]::Join(',', $select))
               FROM ($processing) p
               INNER JOIN SqlSizer.Tables tt ON tt.[Schema] = '" +  $TableInfo.SchemaName + "' and tt.TableName = '" + $TableInfo.TableName + "'
               WHERE p.[Table] = tt.[Id]) rr ON $([string]::Join(' and ', $join))"

     return $sql
}