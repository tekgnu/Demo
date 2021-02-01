##Connect to Azure MSDN Account

### Set Tenant, Subscription, and preferred location
$tenantID=""
$subscriptionID=""
$location=""

$resourceGroupName="rg-prdsecdemo001"
$keyVaultName="kvt-prdmwpdemo002"
$servPrincipalName="keyVaultdemo001"

#Password is intentionally visible
$keySecretforVaultTesting="Access"
$superSercretPasswordforVaultTesting="Diabolical_Safe_Password"
Write-Output "Variables: $tenantID $subscriptionID $location $resourceGroupName $keyVaultName $servPrincipalName $keySecretforVaultTesting $superSercretPasswordforVaultTesting"

Connect-AzAccount -Tenant $tenantID -SubscriptionId $subscriptionID

## Create Resource Group for the Key Vault
New-AzResourceGroup -Name $resourceGroupName -Location $location

$kvRGID=Get-AzResourceGroup -name $resourceGroupName
$srvPrin = New-AzADServicePrincipal `
    -DisplayName $servPrincipalName `
    -Role "Contributor" `
    -Scope $kvRGID.ResourceId

## Get the Service Principal and Password
## Service Principal's GUID
$servID = $srvPrin.ServicePrincipalNames[0]
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($srvPrin.Secret)
$unSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$superSecret = $unSecret | ConvertTo-SecureString -AsPlainText -Force

## Create the Credential 
$credential = [PSCredential]::New($servID,$superSecret)

Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantID

## Create the KeyVault
New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location -Sku 'Standard' `
-SoftDeleteRetentionInDays 7

## Grant the Service Principal the ability to create keys
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $servID -PermissionsToSecrets get,set,delete

## Create the Super Secret Key Value pair as the Service Principal
$secretValue = ConvertTo-SecureString $superSercretPasswordforVaultTesting -AsPlainText -Force
$newSecret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $keySecretforVaultTesting -SecretValue $secretValue
$newSecret.Created.ToLocalTime()

## Now retrieve our Secret - requires Secure string conversion
$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keySecretforVaultTesting
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
try {
   $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}
Write-Output "Key: $keySecretforVaultTesting Value: $secretValueText"


