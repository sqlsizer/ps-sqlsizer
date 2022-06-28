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

     
    $tmp = "CREATE SCHEMA SqlSizerSecure"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $structure = [Structure]::new($info)

    $total = @()
    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -in @('SqlSizer'))
        {
            continue
        }
        $tableSelect = Get-TableSelect -TableInfo $table -Raw $false -IgnoredTables $IgnoredTables -Prefix "t." -AddAs $true -ConvertBit $true
        $hashSelect = Get-TableSelect -TableInfo $table -Raw $false -IgnoredTables $IgnoredTables -Prefix "t." -AddAs $false -ConvertBit $true -Array $true
        $join = GetTableJoin -TableInfo $table -Structure $structure

        if ($null -eq $join)
        {
            continue
        }

        $sql = "CREATE VIEW SqlSizerSecure.$($table.SchemaName)_$($table.TableName) AS SELECT DISTINCT $tableSelect, HASHBYTES('SHA2_512', CONCAT($([string]::Join(', ''|'', ', $hashSelect)))) as row_sha2_512 from $($table.SchemaName).$($table.TableName) t $join"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 

        $total += "SELECT '$($table.SchemaName)' as [Schema], '$($table.TableName)' as [Table], STRING_AGG(CONVERT(VARCHAR(max), row_sha2_512, 2), '|') as [TableHash] FROM SqlSizerSecure.$($table.SchemaName)_$($table.TableName)"
    }

    $sql = "CREATE VIEW SqlSizerSecure.Summary AS $([string]::Join(' UNION ALL ', $total))"
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
}

function GetTableJoin
{
     param (
        [TableInfo]$TableInfo,
        [Structure]$Structure
     )

     $primaryKey = $TableInfo.PrimaryKey
     $signature = $Structure.Tables[$TableInfo]

     if (($signature -eq $null) -or ($signature -eq ""))
     {
        return $null
     }

     $processing = $Structure.GetProcessingName($signature)

     $where = "INNER JOIN SqlSizer.Tables tt ON tt.[Schema] = '" +  $TableInfo.SchemaName + "' and tt.TableName = '" + $TableInfo.TableName + "'
               INNER JOIN $($processing) p ON tt.Id = p.[Table] "

     $i = 0
     foreach ($column in $primaryKey)
     {
        $where += " AND p.Key" + $i + " = " + $column.Name + " " 
        $i += 1
     }

     $where
}
