function Invoke-CredNinja {
<#
    .SYNOPSIS
        Hunt for local admin access in a domain.
        
        Author: Chris King
    .DESCRIPTION
        This script is designed to identify if credentials are valid, invalid, or 
        local admin valid credentials within a domain network and will also check 
        for local admin. It works by attempting to mount C$ on each server using 
        different credentials.
    .PARAMETER Hosts
        The hostnames to attempt to authenticate to in a list.
    .PARAMETER Credentials
        The credentials to use to attempt to authenticate as in a list. The proper 
        format for this is "DOMAIN\Username:Password"
    .PARAMETER NoScan
        If given, it will skip the port scan attempt before trying to authenticate
    .PARAMETER Timeout
        If given, this will set the timeout for the port scan attempt. Default is 
        500ms.
    .EXAMPLE
        PS C:\> gc hosts.txt | Invoke-CredNinja -Credentials 'test\raikia:hunter2','test\user:password'
    .EXAMPLE
        PS C:\> Invoke-CredNinja -Credentials 'test\raikia:hunter2','test\user:password' -Hosts '10.10.10.10','10.20.20.20.','10.30.30.30' -NoScan -Timeout 30000
    .LINK
       https://github.com/Raikia/CredNinja
       https://twitter.com/raikiasec
#>

    [CmdletBinding(DefaultParameterSetName='Credentials')]
    param(
        [Parameter(Mandatory = $True,ParameterSetName="Credentials")]
        [String[]]
        $Credentials = '',
        
        [Parameter(Mandatory = $True, ValueFromPipeline=$True)]
        [String[]]
        $Hosts = '127.0.0.1',
        
        [switch]
        $NoScan = $False,
        
        [int]
        $Timeout = 500
    )

    process {
        "{0,-35}{1,-35}{2,-35}" -f "Host", "Username", "Result"
        "---------------------------------------------------------------------------------------------"
        foreach ($ComputerName in $Hosts) {
            $HostIsValid = $True
            if (!$NoScan) {
                if (!(Test-Port -Computer $ComputerName -Port 445 -Timeout $Timeout)) {
                    "{0}" -f "Host $ComputerName is not accessible on port 445, skipping!"
                    continue
                }
            }
            
            foreach ($Cred in $Credentials) {
                if (!$HostIsValid) {
                    continue
                }
                $Username = $Cred.split(":")[0]
                $Password = $Cred.split(":")[1]
                $test = net use /user:"$Username" "\\$ComputerName\C$" "$Password" 2>&1
                $result = "Unknown";
                if ($test[0].ToString().Contains("completed successfully")) {
                    $result = "LOCAL ADMIN!"
                    $trash = net use "\\$ComputerName\C$" /delete 2>&1
                }
                elseif ($test[0].ToString().Contains("error 86 ")) {
                    $result = "Invalid Password"
                }
                elseif ($test[0].ToString().Contains("error 5 ")) {
                    $result = "Valid"
                }
                elseif ($test[0].ToString().Contains("error 67 ")) {
                    $result = "Unreachable"
                    $HostIsValid = $False
                }
                else {
                    $result = "Other: " + $test[0].ToString()
                }
                "{0,-35}{1,-35}{2,-35}{3,-35}" -f $ComputerName, $Username, $Password, $result
                
            }
        }
    }
}


function Test-Port
{ 
    param ( [string]$Computer, [int]$Port, [int] $Timeout=300 )
     
    $Test = New-Object Net.Sockets.TcpClient
     
    $Test.BeginConnect( $Computer, $Port, $Null, $Null ) | Out-Null
     
    $Time = ( Get-Date ).AddMilliseconds( $Timeout )
     
    While ( -not $Test.Connected -and ( Get-Date ) -lt $Time ) {
        Sleep -Milliseconds 50
    }
     
    #  Return the connection status (Boolean)
    $Test.Connected
         
    # Cleanup
    $Test.Close()
     
} 
