﻿function Copy-Database
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$NewDatabase,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $securePassword = ConvertTo-SecureString -String $ConnectionInfo.Password -AsPlainText -Force
    $psCredential = New-Object System.Management.Automation.PSCredential -argumentlist $ConnectionInfo.Login, $securePassword
    $_ = Copy-DbaDatabase -Database $Database -SourceSqlCredential $psCredential -DestinationSqlCredential $psCredential -Source $ConnectionInfo.Server -Destination $ConnectionInfo.Server -NewName $NewDatabase -BackupRestore -SharedPath (Get-DbaDefaultPath -SqlCredential $psCredential -SqlInstance $ConnectionInfo.Server).Backup 
}

