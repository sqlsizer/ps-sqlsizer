class SqlConnectionInfo
{
    [string]$Server
    [System.Management.Automation.PSCredential]$Credential
    [string]$AccessToken = $null
    [bool]$EncryptConnection = $false
    [SqlConnectionStatistics]$Statistics
}