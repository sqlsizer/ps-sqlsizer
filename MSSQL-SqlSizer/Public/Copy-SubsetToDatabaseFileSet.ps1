function Copy-SubsetToDatabaseFileSet
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [bool]$Secure,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $subsetTables = Get-SubsetTables -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo

    $result = @()
    foreach ($table in $subsetTables)
    {
        $tmpFile = New-TemporaryFile
        $csv = Get-SubsetTableJson -Database $Database -SchemaName $table.SchemaName -TableName $table.TableName -ConnectionInfo $ConnectionInfo -Secure $Secure

        [System.IO.File]::WriteAllText($tmpFile.FullName, $csv, [Text.Encoding]::GetEncoding("utf-8"))
        $fileId = Copy-FileToDatabase -FilePath $tmpFile.FullName -Database $database -ConnectionInfo $connection

        $result += ($fileId, $table)
        Remove-Item $tmpFile.FullName -Force
    }

    return $result
}