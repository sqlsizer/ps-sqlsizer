# Import of module
Import-Module ..\MSSQL-SqlSizer


# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$login = "someuser"
$password = "pass"

# Create connection
$connection = Get-SqlConnectionInfo -Server $server -Login $login -Password $password


# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

# Init SqlSizer structures
Init-Structures -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: 10 persons with first name = 'John'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'John'"
$query.Top = 10
$query.OrderBy = "[`$table].LastName ASC"

# Query 2: All employees with SickLeaveHours > 30
$query2 = New-Object -TypeName Query
$query2.Color = [Color]::Yellow
$query2.Schema = "HumanResources"
$query2.Table = "Employee"
$query2.KeyColumns = @('BusinessEntityID')
$query2.Where = "[`$table].SickLeaveHours > 30"

# Define ignored tables

$ignored = New-Object -Type TableInfo2
$ignored.SchemaName = "dbo"
$ignored.TableName = "ErrorLog"


Init-StartSet -Database $database -ConnectionInfo $connection -Queries @($query, $query2)

# Find subset
Get-Subset -Database $database -ConnectionInfo $connection -Return $false -IgnoredTables @($ignored)


# Create a new db with found subset of data

$newDatabase = "AdventureWorks2019_subset_01"

Copy-Database -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection
Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection
Truncate-Database -Database $newDatabase -ConnectionInfo $connection
Copy-Data -Source $database -Destination  $newDatabase -ConnectionInfo $connection
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection
Shrink-Database -Database $newDatabase -ConnectionInfo $connection

$infoNew = Get-DatabaseInfo -Database $newDatabase -ConnectionInfo $connection -MeasureSize $true

# end of script