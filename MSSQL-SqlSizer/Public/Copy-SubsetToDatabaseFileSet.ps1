function Copy-SubsetToDatabaseFileSet
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$SourceDatabase,

        [Parameter(Mandatory=$true)]
        [string]$TargetDatabase,

        [Parameter(Mandatory=$true)]
        [bool]$Secure,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $subsetTables = Get-SubsetTables -Database $SourceDatabase -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo

    $result = @()
    foreach ($table in $subsetTables)
    {
        $tmpFile = New-TemporaryFile
        $csv = Get-SubsetTableJson -Database $Database -SchemaName $table.SchemaName -TableName $table.TableName -ConnectionInfo $ConnectionInfo -Secure $Secure

        [System.IO.File]::WriteAllText($tmpFile.FullName, $csv, [Text.Encoding]::GetEncoding("utf-8"))
        $fileId = Copy-FileToDatabase -FilePath $tmpFile.FullName -Database $TargetDatabase -ConnectionInfo $connection

        $result += New-Object TableFile -Property @{ FileId = $fileId; TableContent = $table }

        Remove-Item $tmpFile.FullName -Force
    }

    return $result
}