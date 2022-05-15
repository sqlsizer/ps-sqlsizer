function Find-SubsetReachableTables
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [Query[]]$Queries,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $unreachable = Find-SubsetUnreachableTables -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $toReturn = @()
    foreach ($table in $info.Tables)
    {
        $unreachableTable = $unreachable | Where-Object {($_.SchemaName -eq $table.SchemaName) -and ($_.TableName -eq $table.TableName)}
        $isUnreachable = $null -ne $unreachableTable
        
        if ($isUnreachable)
        {   
            $item = New-Object TableInfo2
            
            $item.SchemaName = $table.SchemaName
            $item.TableName = $table.TableName

            $toReturn += $item
        }
    }

    return $toReturn
}