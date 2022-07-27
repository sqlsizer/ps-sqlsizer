![logo](https://avatars.githubusercontent.com/u/96390582?s=100&v=4)
# sqlsizer-mssql

A set of PowerShell scripts to make a copy of a Microsoft SQL database with a subset of data from the original database.

The subsets are highly configurable. The final result is outcome of the original database, the color map and the colors of initial data.

# Use cases 
- Removing unwanted data from database 
- Creating smaller database from production database for development/testing purposes
- GDRP Data Masking 
- Finding all related data to some rows in database
- Tracking changes to data (new/deleted data in other tables)
- Data integrity verification (e.g. using SHA2_512)

# Flow (simplified)

- Step 1: Provide configuration
    - Queries that define initial data (the table rows with colors)
    - (Optional) Color map that allow to configure colors for the data and limits

- Step 2: Execute `Find-Subset` function to find the subset you want
- Step 3: Copy data to new db or just do your own processing of the subset

# Internals
The algorithm used in SqlSizer is a variation of Breadth-first and Depth-first search algorithm applied to a relational database.

All processing is done on Microsoft SQL Server side. No heavy operations are done in Powershell.

The initial set of table rows needs to be defined before the start of the scripts and added to processing tables 
which consists of multiple tables with all possible primary key definitions from the database.

At every iteration the algorithm finds the best set of data with a single color to process based on the number of unprocessed records and depth.
Then data rows are fetched into the appropriate slice table. Later based on the color of the slice and color map the new data rows are added to processing tables.
This process continues until there are no unprocessed rows of any color.

Colors rules:

- Red: find rows that are referenced by the row (recursively)
- Green: find dependent rows on the row (recursively)
- Yellow: split into Red and Green
- Blue: find rows that are required to remove that row (recursively)
- Purple: find referenced (recursively) and dependent data on the row (no-recursively)

![Diagram1](https://user-images.githubusercontent.com/115426/170085145-387fd6c6-9176-4bc4-8ba3-cac2579a1ed3.png)

## Example: Created help structures when subsetting AdventureWorks2019 database
![image](https://user-images.githubusercontent.com/115426/169397874-0d7ee4c2-31da-44a3-846f-e40c9cf10537.png)


# Prerequisites

```powershell
Install-Module sqlserver -Scope CurrentUser
Install-Module dbatools -Scope CurrentUser
Install-Module Az -Scope CurrentUser

```

# Install
Run the following to install SqlSizer-MSSQL from the  [PowerShell Gallery](https://www.powershellgallery.com/packages/SqlSizer-MSSQL).

Please bare in mind that at the moment the SqlSizer-MSSQL is in alpha stage.

To install for all users, remove the -Scope parameter and run in an elevated session:

```powershell
Install-Module MSSQL-SqlSizer -AllowPrerelease -Scope CurrentUser
```

Before running scripts:

```powershell
Import-Module MSSQL-SqlSizer
```

# Examples
Please take a look at examples in *Examples* folder.

## Sample 1 (on-premises SQL server)
```powershell
## Example that shows how to create a new database with the subset of data based on queries which define initial data

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$username = "someuser"
$password = ConvertTo-SecureString -String "pass" -AsPlainText -Force

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Username $username -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

# Install SqlSizer
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

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

# Define ignored tables

$ignored = New-Object -Type TableInfo2
$ignored.SchemaName = "dbo"
$ignored.TableName = "ErrorLog"


Clear-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection -IgnoredTables @($ignored) -DatabaseInfo $info

# Get subset info
Get-SubsetTables -Database $database -Connection $connection -DatabaseInfo $info

Write-Output "Logical reads from db during subsetting: $($connection.Statistics.LogicalReads)" 

# Create a new db with found subset of data

$newDatabase = "AdventureWorks2019_subset_01"

Copy-Database -Database $database -NewDatabase $newDatabase -ConnectionInfo $connection
Disable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Clear-Database -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Copy-DataFromSubset -Source $database -Destination  $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Enable-IntegrityChecks -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Format-Indexes -Database $newDatabase -ConnectionInfo $connection
Uninstall-SqlSizer -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info
Compress-Database -Database $newDatabase -ConnectionInfo $connection

Test-ForeignKeys -Database $newDatabase -ConnectionInfo $connection -DatabaseInfo $info

$infoNew = Get-DatabaseInfo -Database $newDatabase -ConnectionInfo $connection -MeasureSize $true

Write-Output "Subset size: $($infoNew.DatabaseSize)"
$sum = 0
foreach ($table in $infoNew.Tables)
{
    $sum += $table.Statistics.Rows
}

Write-Output "Total rows: $($sum)"
# end of script
```
## Sample 2 (Azure SQL database)

```powershell

## Example that shows how to a subset database in Azure

# Connection settings
$server = "sqlsizer.database.windows.net"
$database = "test01"

Connect-AzAccount
$accessToken = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token

# Create connection
$connection = New-SqlConnectionInfo -Server $server -AccessToken $accessToken

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection -MeasureSize $true

# Install SqlSizer
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: 10 top customers
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "SalesLT"
$query.Table = "Customer"
$query.KeyColumns = @('CustomerID')
$query.Top = 10

Clear-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find subset
Find-Subset -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Get subset info
Get-SubsetTables -Database $database -Connection $connection -DatabaseInfo $info

Write-Output "Logical reads from db during subsetting: $($connection.Statistics.LogicalReads)" 

```
