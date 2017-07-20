function Set-HANodeState
{
    [CmdletBinding()]
    param(
        # HAProxy stats page
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [uri]
        $StatsURI,
        
        # HAProxy backend name
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BackendName,
        
        # Server name
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NodeName,
        
        # Node command
        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateSet('ready', 'maint', 'drain')]
        [string]
        $Command,

        # Admin credentials
        [Parameter(Mandatory = $true, Position = 4)]
        [System.Management.Automation.PSCredential]
        $Credential
        
    )
     
    try
    {         
        Write-Verbose "Get HAProxy admin page"
        $adminPage = Invoke-WebRequest -Uri $StatsURI -Credential $Credential -ErrorAction Stop
     
        Write-Verbose "Get HAProxy backend managing form"
        $backendForm = $adminPage.ParsedHtml.getElementsByTagName('form')|Where-Object { 
            $_.getElementsByClassName('px')|Where-Object { 
                $_.textContent -eq $BackendName
            } 
        }

       
        $backendID = $backendForm.getElementsByTagName('input')|Where-Object Name -eq 'b'|Select-Object -ExpandProperty Value
        Write-Verbose "HAProxy backend $backendID"

        Write-Verbose "Send command $Command"
        $setMaintenanceParam = @{
            Uri = $StatsURI
            MaximumRedirection = 0
            Method = 'Post' 
            Body = @{
                s = $NodeName
                action = $Command
                b = $backendID
            }
            Credential = $Credential
        }

        $responseStatus = (Invoke-WebRequest @setMaintenanceParam -ErrorAction Stop).Headers.Location
    }
    catch
    {
        throw $_
    }

    if ($responseStatus -ne '/;st=DONE')
    {
        throw "Error executing command $Command for server $BackendName/$NodeName"
    }

    return $true

}