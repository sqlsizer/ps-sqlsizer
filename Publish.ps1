param (
    [string] $apiKey
)

Publish-Module `
    -Path "." `
    -NuGetApiKey $apiKey `
    -Exclude @('Examples\AdventureWorks2019_example_01.ps1',
        'Examples\AdventureWorks2019_example_02.ps1',
        'Examples\AdventureWorks2019_example_03.ps1',
        'Examples\AdventureWorks2019_example_04.ps1',
        'Examples\AdventureWorks2019_example_05.ps1',
        'Examples\AdventureWorks2019_example_06.ps1',
        'Examples\AdventureWorks2019_example_07.ps1',
        'Examples\AdventureWorks2019_example_08.ps1',
        'Examples\AdventureWorks2019_example_09.ps1',
        'Examples\AdventureWorks2019_example_10.ps1',
        'Examples\AdventureWorks2019_example_11.ps1',
        'Examples\AdventureWorks2019_example_12.ps1',
        'Examples\AdventureWorks2019_example_13.ps1',
        'Examples\AzureAdventureWorksLT_example_01.ps1')
    -Verbose -Force