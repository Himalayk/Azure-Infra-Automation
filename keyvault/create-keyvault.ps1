<#
Require Powershell modules
Install-Module Az.Resources
Az.Accounts
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]
    $KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]
    $Location,

    [Parameter(Mandatory = $true)]
    [string]
    $AppServicePlanName,

    [Parameter(Mandatory = $true)]
    [string]
    $AzureSubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]
    $AzureDirectoryId,

    [Parameter(Mandatory = $true)]
    [string]
    $DeploymentAppId,

    [Parameter(Mandatory = $true)]
    [securestring]
    $DeploymentAppSecret
)

# Session configuration
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

Write-Host "Importing required Azure PowerShell modules"
Import-Module Az.Accounts
Import-Module Az.Resources

Write-Host "Script Execution Started." -ForegroundColor Yellow

$credentials = New-Object -TypeName System.Management.Automation.PSCredential($DeploymentAppId, $DeploymentAppSecret)

#login with service principal
try {
    Write-Verbose "Connecting to the Azure Subscription $AzureSubscriptionId."
    Connect-AzAccount -Credential $credentials -TenantId $AzureDirectoryId -Subscription $AzureSubscriptionId -ServicePrincipal -ErrorAction Stop -Verbose | Out-Host
    Write-Verbose "Established connection to Azure Subscription."
}
catch {
    Write-Host "Failed to connect to the Azure Subscription. Run 'Connect-AzAccount -Subscription $AzureSubscriptionId' to manually troubleshoot." -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
}

Write-Host "Creating resource group" $ResourceGroupName
New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force
    

Write-Host "Updating parameters values"
$webappParameters = Get-Content -Path "$PSScriptRoot\webapp.parameters.json" | ConvertFrom-Json
$deploymentParameters = Get-Content -Path "$PSScriptRoot\templates\deployment.parameters.json" | ConvertFrom-Json

# Update web app tags parameters
$webappParameters.parameters.webApp.value.tags.DeployedBy = $DeploymentAppId
$webappParameters.parameters.webApp.value.tags.resourceGroupName = $ResourceGroupName

#Update deployment parameters
$deploymentParameters.parameters.webAppName.value = $webAppName
$deploymentParameters.parameters.appServicePlanName.value = $AppServicePlanName
$deploymentParameters.parameters.sku.value = $webappParameters.parameters.webApp.value.sku
$deploymentParameters.parameters.tags.value = $webappParameters.parameters.webApp.value.tags
$deploymentParameters.parameters.skuCode.value = $webappParameters.parameters.webApp.value.skuCode
$deploymentParameters.parameters.AppSettings.value = $webappParameters.parameters.webApp.value.AppSettings

$ParameterFile = [System.IO.Path]::GetTempFileName()
( $deploymentParameters | ConvertTo-Json -Depth 20 ) -replace "\\u0027", "'" -replace "\\u0026", "&" | Out-File $ParameterFile -Force
$parameters
Write-Host "Initiating Web App creation"
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
    -TemplateFile $PSScriptRoot\templates\webapp.json `
    -TemplateParameterFile $ParameterFile -Name $ResourceGroupName `
    -ErrorAction Stop -Mode Incremental -DeploymentDebugLogLevel All -Verbose -Force | Out-Null

Write-Host "Web App has been create successfully"

Write-Host "Script Execution Completed"