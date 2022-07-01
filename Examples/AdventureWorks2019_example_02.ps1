## Example that shows how to find data needed to remove initial data set

# Import of module
Import-Module ..\MSSQL-SqlSizer

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$username = "someuser"
$password = ConvertTo-SecureString -String "pass" -AsPlainText -Force

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Username $username -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection

# Install SqlSizer
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Define start set

# Query 1: All persons with first name = 'Michael'
$query = New-Object -TypeName Query
$query.Color = [Color]::Blue
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'Michael'"

$ignored = New-Object -Type TableInfo2
$ignored.SchemaName = "Sales"
$ignored.TableName = "Store"

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info

# Find smallest subset that allows to remove start set from the database
Find-Subset -Database $database -ConnectionInfo $connection -DatabaseInfo $info -IgnoredTables @($ignored)

Get-SubsetTables -Database $database -Connection $connection -DatabaseInfo $info
$rows = Get-SubsetTableRows -Database $database -Connection $connection -DatabaseInfo $info -SchemaName "Sales" -TableName "Customer" -AllColumns $true -IgnoredTables  @($ignored)

foreach ($row in $rows)
{
    $i = 0
    foreach ($column in $row.ItemArray)
    {
        Write-Output "Column $($row.Table.Columns[$i]) = '$($column)'"
        $i += 1
    }
    Write-Output "==========="
}

# end of script