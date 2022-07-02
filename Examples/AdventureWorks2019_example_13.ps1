## Example that shows how to get info about all schemas from db

# Import of module
Import-Module ..\Module\MSSQL-SqlSizer

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$username = "someuser"
$password = ConvertTo-SecureString -String "pass" -AsPlainText -Force

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Username $username -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

Write-Output "SqlSizer subset schemas"

foreach ($schema in $info.AllSchemas)
{
    if ($schema.StartsWith("SqlSizer_subset_"))
    {
        Write-Output "Schema: $schema"

        Remove-Schema -Database $database -SchemaName $schema -ConnectionInfo $connection
    }
}

# end of script