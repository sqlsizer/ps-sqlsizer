## Example that shows how to check how many tables are reachable by queries

# Import of module
Import-Module ..\MSSQL-SqlSizer

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$login = "someuser"
$password = "pass"

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Login $login -Password $password
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection


# Query 1: All persons with first name = 'Michael'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'Michael'"


$testResult = Test-Queries -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info -EdgeMode $true