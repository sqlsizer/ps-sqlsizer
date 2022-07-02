## Example that shows how to create a new database with the subset of data based on queries which define initial data

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

$newDatabase = "AdventureWorks2019_subset_05"

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
Write-Output "==================="

Write-Output "Secure CSV for Person.Person:"
Write-Output $(Get-SubsetTableCsv -Database $database -SchemaName "Person" -TableName "Person" -DatabaseInfo $info -ConnectionInfo $connection -Secure $true -SkipHeader $false)

Write-Output "Secure Json for Person.Person:"
Write-Output $(Get-SubsetTableJson -Database $database -SchemaName "Person" -TableName "Person" -DatabaseInfo $info -ConnectionInfo $connection -Secure $true)

Write-Output "Secure Xml for Person.Person:"
$xml = Get-SubsetTableXml -Database $database -SchemaName "Person" -TableName "Person" -DatabaseInfo $info -ConnectionInfo $connection -Secure $true
Write-Output $xml.OuterXml

# end of script