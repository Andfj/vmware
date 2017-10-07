<#
.Synopsis
   Create a virtual machine(s) in vCenter
.DESCRIPTION
   Create a virtual machine(s) in vCenter
.EXAMPLE
   New-vServer -Name 'server-name' -IPAddress '192.168.2.50' -DataCenter 'DatacenterNL'
.EXAMPLE
   Import-Csv -Path '.\computer.txt' -Delimiter ';' | New-vServer -DataCenter 'DatacenterUK'
#>
function New-vServer
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet("DatacenterUK", "DatacenterNL" , "DatacenterHK")]
        [string]$DataCenter,

        [Parameter(Mandatory=$false)]
        [string]$folderInVmware,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$IPAddress,

        [Parameter(Mandatory=$false)]
        [string]$IPAdressManagement,

        [Parameter(Mandatory=$false)]
        [string]$vCPU = 2,

        [Parameter(Mandatory=$false)]
        [string]$MemoryInGB = 4


    )

    Begin
    {
        Write-Output 'Trying to connect to vCenter'        

        $cred = Get-Credential -Credential "domain\user"

        Connect-VIServer -Server "vCenter" -Protocol https  -Credential $cred | Out-Null
        $datastore = Get-Datastore -Name "Datastore"

        if ($DataCenter -eq 'DatacenterUK') { $subnetMask = '255.255.255.0'; $gateway = '192.168.1.1'; $dnsServers = '192.168.1.4', '192.168.1.5' }
        if ($DataCenter -eq 'DatacenterNL') { $subnetMask = '255.255.255.0'; $gateway = '192.168.2.1'; $dnsServers = '192.168.2.4', '192.168.2.5' }
        if ($DataCenter -eq 'DatacenterHK') { $subnetMask = '255.255.255.0'; $gateway = '192.168.3.1'; $dnsServers = '192.168.3.4', '192.168.3.5' }
    }

    Process
    {
        

        $cluster = Get-Cluster -Location $DataCenter
        $folder = Get-Folder -Name "Prod Servers" -Location $DataCenter
        $template = Get-Template -Name "template-Win2012R2-20170625" -Location $DataCenter

        [string]$vmName = $Name
        [string]$vmIPaddress = $IPAddress
        [string[]]$VMs += $vmName
        $vmHost = Get-VMHost -Location $DataCenter -State Connected | Select-Object -First 1 
        
        $OSSpec = New-OSCustomizationSpec -AdminPassword "Pa$$w0rd" -AutoLogonCount 1 -ChangeSid -Domain "domain.local" -DomainCredentials $cred -FullName "Administrator" `
                  -NamingPrefix $vmName  -NamingScheme fixed -OrgName "ORG" -OSType Windows -ProductKey "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE" -TimeZone '090' -Type NonPersistent 

        $nicMapping = $OSSpec | Get-OSCustomizationNicMapping | where { $_.Position -eq '1' } 
        $nicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $vmIPAddress -SubnetMask $subnetMask -DefaultGateway $gateway -Dns $dnsServers

        [array]$vmTask += New-VM -Name $vmName -VMHost $vmHost -Datastore $datastore -Template $template -ResourcePool $cluster -DiskStorageFormat Thin -OSCustomizationSpec $OSSpec  -Location $folder -ErrorAction Stop -RunAsync
        
    }

    End
    {
        Wait-Task -Task $vmTask
        Write-Output "Virtual machnes: $($VMs -join ', ') were created"

    }
}