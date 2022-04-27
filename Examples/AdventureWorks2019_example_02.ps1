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

# Query 1: All persons with first name = 'Michael'
$query = New-Object -TypeName Query
$query.Color = [Color]::Blue
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "x.FirstName = 'Michael'"

Init-StartSet -Database $database -ConnectionInfo $connection -Queries @($query)

# Find smallest subset that allows to remove start set from the database
Get-Subset -Database $database -ConnectionInfo $connection -Return $false

Copy-Database -Database $database -Prefix "S." -ConnectionInfo $connection
Disable-IntegrityChecks -Database ("S." + $database) -ConnectionInfo $connection
Delete-Data -Source $database -Target ("S." + $database) -ConnectionInfo $connection
Enable-IntegrityChecks -Database ("S." + $database) -ConnectionInfo $connection

# end of script