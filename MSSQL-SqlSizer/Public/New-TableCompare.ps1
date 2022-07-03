function New-TableCompare
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName1,

        [Parameter(Mandatory=$true)]
        [string]$TableName1,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName2,

        [Parameter(Mandatory=$true)]
        [string]$TableName2,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $table1 = $info.Tables | Where-Object { ($_.SchemaName -eq $SchemaName1) -and ($_.TableName -eq $TableName1) }
    $table2 = $info.Tables | Where-Object { ($_.SchemaName -eq $SchemaName2) -and ($_.TableName -eq $TableName2) }

    if ([string]::Join(',', $table1.Columns) -ne [string]::Join(',', $table2.Columns))
    {
        Write-Output "Tables have different schema."
        return
    }

    $schemaExists = Test-SchemaExists -SchemaName "SqlSizerCompare" -Database $Database -ConnectionInfo $ConnectionInfo
    if ($schemaExists -eq $false)
    {
        $sql = "CREATE SCHEMA SqlSizerCompare"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $compareId = (New-Guid).ToString().Replace('-', '_')

    $sql = "CREATE TABLE SqlSizerCompare.Comparision_$compareId ("
    foreach ($primaryColumn in $table1.PrimaryKey)
    {
        $sql += $primaryColumn.Name + " " + $primaryColumn.DataType + " NOT NULL, "
    }
    $sql += " [Result] int NOT NULL)"
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    
    $sql = "ALTER TABLE SqlSizerCompare.TableCompare_$compareId ADD PRIMARY KEY " + [string]::Join(",", $table1.PrimaryKey)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    # prepare
    $primary = @()
    $cond = @()
    $cond2 = @()
    $columns = @()
    $columnsOr = @()
    foreach ($primaryColumn in $table1.PrimaryKey)
    {
        $primary += "t." + $primaryColumn
        $cond += "t." + $primaryColumn + " = " + "t2." + $primaryColumn
        $cond2 += "t2." + $primaryColumn  + " IS NULL "
    }

    foreach ($column in $table1.Columns)
    {
        if ($column.DataType -eq 'xml')
        {
            $columns += "((CONVERT(nvarchar(max), t." + $column + ") = CONVERT(nvarchar(max), t2." + $column + ")) or (t.$column is null and t2.$column is null))"
            $columnsOr += "(CONVERT(nvarchar(max), t." + $column + ") <> CONVERT(nvarchar(max), t2." + $column + "))"
        }
        else
        {
            $columns += "((t.$column=t2.$column) or (t.$column is null and t2.$column is null))"
            $columnsOr += "(t.$column <> t2.$column)"
        }
    }

    # only in schema1.table1
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), -1 FROM $SchemaName1.$TableName1 t LEFT JOIN  $SchemaName2.$TableName2 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" and ", $cond2)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    # only in schem2.table2
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), 1 FROM $SchemaName2.$TableName2 t LEFT JOIN  $SchemaName1.$TableName1 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" and ", $cond2)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    
    # same
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), 0 FROM $SchemaName1.$TableName2 t INNER JOIN  $SchemaName2.$TableName1 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" and ", $columns)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    # different
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), 2 FROM $SchemaName1.$TableName2 t INNER JOIN  $SchemaName2.$TableName1 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" or ", $columnsOr)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    return $compareId
}