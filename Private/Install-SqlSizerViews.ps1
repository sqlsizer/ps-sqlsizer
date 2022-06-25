function Install-SqlSizerViews
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

     
    $tmp = "CREATE SCHEMA SqlSizerResult"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $structure = [Structure]::new($info)

    foreach ($table in $info.Tables)
    {
        if ($table.SchemaName -in @('SqlSizer'))
        {
            continue
        }
        $tableSelect = Get-TableSelect -TableInfo $table -Raw $false -IgnoredTables $IgnoredTables -Prefix "t."
        $join = GetTableJoin -TableInfo $table -Structure $structure

        if ($null -eq $join)
        {
            continue
        }

        $sql = "CREATE VIEW SqlSizerResult.$($table.SchemaName)_$($table.TableName) AS SELECT DISTINCT $tableSelect from $($table.SchemaName).$($table.TableName) t $join"
        $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo 
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
