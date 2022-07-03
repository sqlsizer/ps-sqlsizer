function Uninstall-SqlSizer
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

    Remove-Schema -Database $Database -SchemaName "SqlSizerResult" -ConnectionInfo $ConnectionInfo
    Remove-Schema -Database $Database -SchemaName "SqlSizerSecure" -ConnectionInfo $ConnectionInfo
    Remove-Schema -Database $Database -SchemaName "SqlSizerExport" -ConnectionInfo $ConnectionInfo
    Remove-Schema -Database $Database -SchemaName "SqlSizer" -ConnectionInfo $ConnectionInfo
}