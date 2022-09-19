// Bicep-DevTest-TestScript.bicep
// Azure PowerShell & CLI Script
// Azure Subscription: IngramLab
// By Jody Ingram


// Resource Format Start

// Pulls in API Version: In this case: deploymentScripts@2020-10-01.
resource resourceGroup 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'DevTestString'
  location: 'resourceGroup().location'
  tags: { // Defining tags in advance
    tagName1: 'DevTag1' 
    tagName2: 'DevTag2'
    tagName3: 'DevTag3'
  }
    azCliVersion: '2.40.0'
    retentionInterval: 
  kind: 'AzureCLI'
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
  }

// Resource Format End


// Creates the deployment group

az deployment group create 
  --name Ingram-DG-Test 
  --resource-group RG-Ingram-Test 
  --template-file main.bicep 
  --parameters storageAccountType=Standard_GRS

// Subscription level script deployment
New-AzResourceGroupDeployment -TemplateFile Bicep-DevTest-TestScript.bicep
