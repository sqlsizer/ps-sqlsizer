function Clear-SqlSizer
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
        TRUNCATE TABLE SqlSizer.Operations"
    Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo

    $structure = [Structure]::new($info)

    foreach ($signature in $structure.Signatures.Keys)
    {
        $slice = $structure.GetSliceName($signature)
        $tmp = "IF OBJECT_ID('$($slice)') IS NOT NULL  
            TRUNCATE TABLE $($slice)"
        Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }

    foreach ($signature in $structure.Signatures.Keys)
    {
        $processing = $structure.GetProcessingName($signature)
        $tmp = "IF OBJECT_ID('$($processing)') IS NOT NULL  
            TRUNCATE TABLE $($processing)"
        Execute-SQL -Sql $tmp -Database $Database -ConnectionInfo $ConnectionInfo
    }
}