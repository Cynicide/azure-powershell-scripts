# Create an Azure Storage account that conforms to our existing environment and then output the Access Key and accout name.

Param(
# Names should be alphanumeric and have enough space left for our prefix
[parameter(Mandatory=$true)]
[ValidatePattern("^[a-zA-Z0-9-]+$")]
[ValidateLength(1,16)]
[String]
$StorageName,

[parameter(Mandatory=$true)]
[ValidateSet("AUS","US")]
[String]
$Region
)

# Region Specific Parameters

if ($Region -eq "AUS" )
{
    $Location = "Australia East"
}

if ($Region -eq "US" )
{
    $Location = "West US"
}

# Azure 
$SubscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$AzureAccountName ="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$AzurePassword = ConvertTo-SecureString "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -AsPlainText -Force
$TenantID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# StorageAccount
$SAPrefix = "myprefix"
$StorageAccountName = $SAPrefix + $StorageName

$ResourceGroupName = "myresourcegroup"
# In our case we want LRS for data sovereignty issues
$SkuName = "Standard_LRS"

# Login
Write-Host "================= Logging in ================="

# Login using an Azure Service Principal: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal
$PSCred = New-Object System.Management.Automation.PSCredential($AzureAccountName, $AzurePassword)
Add-AzureRmAccount -Credential $PSCred -TenantId $TenantID -ServicePrincipal
Get-AzureRmLog -StartTime (Get-Date).AddMinutes(-10)

# Attach to Subscription
Write-Host "================= Selecting Subscription ID " $SubscriptionId " ================="
Select-AzureRmSubscription -SubscriptionID $SubscriptionId

# Check Name Availability

$NameAvailability = Get-AzureRmStorageAccountNameAvailability -Name $StorageAccountName

if ($NameAvailability.NameAvailable -eq "True")
{
    # Create Storage Account
    Write-Host "================= Creating Storage Account " $StorageAccountName " ================="
    New-AzureRmStorageAccount -Location $Location -Name $StorageAccountName.ToLower() -ResourceGroupName $ResourceGroupName -SkuName $SkuName

    # Get Storage Key
    $StorageKey = Get-AzureRmStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName

    # Connect to Storage Account
    $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKey[0].Value

    # Create Some Containers
    Write-Host "================= Creating Storage Containers ================="
    New-AzureStorageContainer -Context $StorageContext -Name container1
    New-AzureStorageContainer -Context $StorageContext -Name container2;
    New-AzureStorageContainer -Context $StorageContext -Name container3;

    Write-Host "Complete!"
    Write-Host "Storage Account Name: " $StorageAccountName
    Write-Host "Storage Key: " $StorageKey[0].Value
}
else
{
    Write-Host "ERROR: Requested Name Unavailable" -ForegroundColor Red
}