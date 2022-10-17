function Get-SubsetHashSummary
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$SessionId,

        [Parameter(Mandatory = $true)]
        [string]$Database,

        [Parameter(Mandatory = $true)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory = $false)]
        [boolean]$Negation = $false,

        [Parameter(Mandatory = $true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $sql = "SELECT [Schema]
                ,[Table]
                ,[TableHash]
        FROM [SqlSizer_$SessionId].[Secure_Summary]
        WHERE TableHash IS NOT NULL
        ORDER BY [Schema], [Table]"

    $rows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    $hashes = @()
    foreach ($row in $rows)
    {
        $hashes += [pscustomobject] @{
            SchemaName = $row.Schema
            TableName  = $row.Table
            Hash    = $row.TableHash
        }
    }
    return $hashes

}