## Example that shows how to remove all SqlSizer schemas

# Import of module
Import-Module ..\MSSQL-SqlSizer\MSSQL-SqlSizer

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$username = "someuser"
$password = ConvertTo-SecureString -String "pass" -AsPlainText -Force

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Username $username -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

foreach ($schema in $info.AllSchemas)
{
    if ($schema.StartsWith("SqlSizer"))
    {
        Remove-Schema -Database $database -SchemaName $schema -ConnectionInfo $connection
    }
}

# end of script