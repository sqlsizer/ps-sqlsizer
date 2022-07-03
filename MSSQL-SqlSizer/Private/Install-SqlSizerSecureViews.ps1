function Install-SqlSizerSecureViews
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

    $schemaExists = Test-SchemaExists -SchemaName "SqlSizerSecure" -Database $Database -ConnectionInfo $ConnectionInfo
    if ($schemaExists -eq $false)
    {
        $tmp = "CREATE SCHEMA SqlSizerSecure"
        $null = Invoke-SqlcmdEx -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $structure = [Structure]::new($info)

    $total = @()
    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName.StartsWith('SqlSizer'))
        {
            continue
        }
        $tableSelect = Get-TableSelect -TableInfo $table -Conversion $true -IgnoredTables $IgnoredTables -Prefix "t." -AddAs $true -SkipGenerated $false
        $hashSelect = Get-TableSelect -TableInfo $table -Conversion $true -IgnoredTables $IgnoredTables -Prefix "t." -AddAs $false -Array $true -SkipGenerated $false
        $join = GetTableJoin -TableInfo $table -Structure $structure

        if ($null -eq $join)
        {
            continue
        }

        $sql = "CREATE VIEW SqlSizerSecure.$($table.SchemaName)_$($table.TableName) AS SELECT $tableSelect, HASHBYTES('SHA2_512', CONCAT($([string]::Join(', ''|'', ', $hashSelect)))) as row_sha2_512 FROM $($table.SchemaName).$($table.TableName) t INNER JOIN $join"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

        $total += "SELECT '$($table.SchemaName)' as [Schema], '$($table.TableName)' as [Table], STRING_AGG(CONVERT(VARCHAR(max), row_sha2_512, 2), '|') as [TableHash] FROM SqlSizerSecure.$($table.SchemaName)_$($table.TableName)"
    }

    $sql = "CREATE VIEW SqlSizerSecure.Summary AS $([string]::Join(' UNION ALL ', $total))"
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
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
               FROM $($processing) p
               INNER JOIN SqlSizer.Tables tt ON tt.[Schema] = '" +  $TableInfo.SchemaName + "' and tt.TableName = '" + $TableInfo.TableName + "'
               WHERE p.[Table] = tt.[Id]) rr ON $([string]::Join(' and ', $join))"

     return $sql
}