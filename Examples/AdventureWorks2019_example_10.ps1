## Example that shows how copy schema

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

Remove-Schema -Database $database -ConnectionInfo $connection -SchemaName "Person6"
New-SchemaFromDatabase -SourceDatabase $database -TargetDatabase $database -ConnectionInfo $connection -SchemaName "Person" -NewSchemaName "Person6" -CopyData $false -DatabaseInfo $info

# end of script