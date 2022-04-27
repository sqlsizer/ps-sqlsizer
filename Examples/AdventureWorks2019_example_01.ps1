# Import of module
Import-Module ..\MSSQL-SqlSizer -Verbose


# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$login = "someuser"
$password = "pass"

# Create connection
$connection = Get-SqlConnectionInfo -Server $server -Login $login -Password $password


# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection

# Init SqlSizer structures
Init-Structures -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: All persons with first name = 'Mary'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "x.FirstName = 'Mary'"

# Query 2: All employees with SickLeaveHours > 30
$query2 = New-Object -TypeName Query
$query2.Color = [Color]::Yellow
$query2.Schema = "HumanResources"
$query2.Table = "Employee"
$query2.KeyColumns = @('BusinessEntityID')
$query2.Where = "x.SickLeaveHours > 30"

Init-StartSet -Database $database -ConnectionInfo $connection -Queries @($query, $query2)

# Find subset
Get-Subset -Database $database -ConnectionInfo $connection -Return $false


# Create a new db with found subset of data
Copy-Database -Database $database -Prefix "S." -ConnectionInfo $connection
Disable-IntegrityChecks -Database ("S." + $database) -ConnectionInfo $connection
Truncate-Database -Database ("S." + $database) -ConnectionInfo $connection
Copy-Data -Source $database -Destination ("S." + $database) -ConnectionInfo $connection
Enable-IntegrityChecks -Database ("S." + $database) -ConnectionInfo $connection


# end of script