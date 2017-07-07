# Creates a VM and puts it an a pre-existing network subnet based on its role
#
Param(
[parameter(Mandatory=$true)]
[ValidatePattern("^[a-zA-Z0-9-]+$")]
[String]
$ComputerName,

[parameter(Mandatory=$true)]
[ValidateSet("AUS","US")]
[String]
$Region,

[parameter(Mandatory=$true)]
[ValidateSet("Stage","Prod")]
[String]
$Env
)

# Region and Environment Specific Parameters

if ($Region -eq "AUS" )
{
    switch($Env)
    {
    Stage {
        $Location = "Australia East"
        $VirtualNetworkName = "MyNetwork"
        $VNResourceGroupName = "MyNetworkResourceGroup"
        $VNSubnetName = "MyStagingSubnet"
        $NetworkSecurityGroupName = "MyStagingSecurityGroup"
        $NetworkSecurityGroupResourceGroupName = "MySecurityGroupResourceGroup"
        }
    Prod {
        $Location = "Australia East"
        $VirtualNetworkName = "MyNetwork"
        $VNResourceGroupName = "MyNetworkResourceGroup"
        $VNSubnetName = "MyProductionSubnet"
        $NetworkSecurityGroupName = "MyProductionSecurityGroup"
        $NetworkSecurityGroupResourceGroupName = "MySecurityGroupResourceGroup"
        }
    }
}

if ($Region -eq "US" )
{
    switch($Env)
    {
    Stage {
        # We don't have stage network in the US so do not proceed.
        Write-Host "Exception Thrown: Stage not supported in the US at this time."
        throw "Stage not supported in the US at this time."
        }
    Prod {
        $Location = "West US"
        $VirtualNetworkName = "MyUSNetwork"
        $VNResourceGroupName = "MyUSNetworkResourceGroup"
        $VNSubnetName = "MyUSProdSubnet"
        $NetworkSecurityGroupName = "MyUSSecurityGroup"
        $NetworkSecurityGroupResourceGroupName = "MyUSSecurityGroupResourceGroup"
        }
    }
}


# Azure 
$SubscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$AzureAccountName ="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$AzurePassword = ConvertTo-SecureString "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -AsPlainText -Force
$TenantID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# VM
$ResourceGroupName = $ComputerName
$VMSize = "Standard_DS1_v2"

# Networking
$PublicIPMethod = "Static"
$PublicIPName = $ComputerName + "-publicip"
$NICName = $ComputerName + "-nic"

# Storage
$StorageAccountName = $ComputerName.ToLower() + "store"
$StorageAccountName = $StorageAccountName -replace '[-]',''
$OSDiskName = $ComputerName + "OSDisk"

# OS
$OSPublisher = "Canonical"
$OSOffer = "UbuntuServer"
$OSSKU = "16.04-LTS"
$OSVersion = "latest"

# Credentials
$UserName = "myusername"
$Password = ConvertTo-SecureString -String "mypassword" -AsPlainText -Force

Write-Host "Creating " $ComputerName " in " $Location

# Login
Write-Host "================= Logging in ================="

# Login using an Azure Service Principal: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal
$PSCred = New-Object System.Management.Automation.PSCredential($AzureAccountName, $AzurePassword)
Add-AzureRmAccount -Credential $PSCred -TenantId $TenantID -ServicePrincipal
Get-AzureRmLog -StartTime (Get-Date).AddMinutes(-10)

# Attach to Subscription
Write-Host "================= Selecting Subscription ID " $SubscriptionId " ================="
Select-AzureRmSubscription -SubscriptionID $SubscriptionId;

# Create Resource Group
Write-Host "================= Creating Resource Group " $ResourceGroupName " ================="
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location;

# Define Network
Write-Host "================= Getting Virtual Network " $VirtualNetworkName " ================="
$VNET = Get-AzureRMVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VNResourceGroupName
Write-Host "================= Getting Subnet " $VNSubnetName " ================="
$SubnetConfig = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNET -Name $VNSubnetName
Write-Host "================= Creating PublicIP " $PublicIPName " ================="
$PublicIP = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod $PublicIPMethod -IdleTimeoutInMinutes 4 -Name $PublicIPName
Write-Host "================= Getting Network Security Group " $NetworkSecurityGroupName " ================="
$NSG = Get-AzureRmNetworkSecurityGroup -Name $NetworkSecurityGroupName  -ResourceGroupName $NetworkSecurityGroupResourceGroupName
Write-Host "================= Creating NIC " $NICName " ================="
$NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $location -SubnetId $SubnetConfig.Id -PublicIpAddressId $PublicIP.Id -NetworkSecurityGroupId $NSG.Id

#Create Storage Account
Write-Host "================= Creating Storage Account " $StorageAccountName " ================="
Get-AzureRmStorageAccountNameAvailability $StorageAccountName
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -SkuName "Standard_LRS" -Kind "Storage" -Location $Location
Write-Host "================= Setting OS Disk Location =================" 
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"

# Create Virtual Machine Configuration
Write-Host "================= Setting VM Credentials ================="  
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential($UserName, $Password)
Write-Host "================= Creating VM Configuration =================" 
$VMConfig = New-AzureRmVMConfig -VMName $ComputerName -VMSize $VMSize | Set-AzureRmVMOperatingSystem -Linux -ComputerName $ComputerName -Credential $Credentials | Set-AzureRmVMSourceImage -PublisherName $OSPublisher -Offer $OSOffer -Skus $OSSKU -Version $OSVersion | Add-AzureRmVMNetworkInterface -Id $NIC.Id | Set-AzureRmVMOSDisk -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

# Create Virtual Machine
Write-Host "================= Creating Virtual Machine =================" 
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VMConfig
