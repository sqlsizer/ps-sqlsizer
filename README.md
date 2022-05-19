![logo](https://avatars.githubusercontent.com/u/96390582?s=100&v=4)
# mssql-sqlsizer

A set of PowerShell scripts to make a copy of a Microsoft SQL database with a subset of data from the original database.

Additionally the scripts are able to:
- Delete selected data from the database quickly (respecting all foreign keys)
- Extract a subset of the data from the database (currently only to XML)

# Flow (simplified)

- Step 1: Provide configuration
    - Queries that define initial data (the table rows with colors)
    - (Optional) Color map that allow to configure forced colors for the tables

- Step 2: Execute `Find-Subset` function to find the subset you want
- Step 3: Copy data to new db or just do your own processing of the subset

# Internals
The algorithm used in SqlSizer is a variation of Breadth-first and Depth-first search search algorithm applied to a relational database.

All processing is done on SQL Server side. No heavy operations are done in Powershell.

The initial set of table rows needs to be defined before the start of the scripts and added to processing tables 
which consists of multiple tables with all possible primary key definitions from the database.

At every iteration the algorithm finds the best set of data with a single color to process based on the number of unprocessed records and depth.
Then data rows are fetched into the slices tables. Later based on the color of the slice the appropriate rows are added to processing tables.
This process continues until there are no unprocessed rows of any color.

Colors have following meaning:

- Red: find all rows that are referenced by the row (recursively)
- Green: find all dependent rows on the row
- Yellow: find all referenced and dependent data on the row
- Blue: find all rows that are required to remove that row (recursively)

## Example: Created help structures when subsetting AdventureWorks2019 database
![image](https://user-images.githubusercontent.com/115426/168351591-df226e88-8098-46fa-bb4a-bfc735915d1e.png)


# Prerequisites

```powershell
Install-Module sqlserver -Scope CurrentUser # if not present
Install-Module dbatools -Scope CurrentUser
```

# Examples
Please take a look at examples in *Examples* folder.

## Sample
```powershell
# Import of module
Import-Module ..\MSSQL-SqlSizer -Verbose


# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$login = "someuser"
$password = "pass"

# New connection info
$connection = New-SqlConnectionInfo -Server $server -Login $login -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection

# Init SqlSizer
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: All persons with first name = 'Mary'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'Mary'"

# Query 2: All employees with SickLeaveHours > 30
$query2 = New-Object -TypeName Query
$query2.Color = [Color]::Yellow
$query2.Schema = "HumanResources"
$query2.Table = "Employee"
$query2.KeyColumns = @('BusinessEntityID')
$query2.Where = "[`$table].SickLeaveHours > 30"

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query, $query2)

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection

# Create a new db with found subset of data

$newDatabase = "AdventureWorks2019_subset_01"

Copy-Database -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection
Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection
Clear-Database -Database $newDatabase -ConnectionInfo $connection
Copy-Data -Source $database -Destination  $newDatabase -ConnectionInfo $connection
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection

# end of script
```
