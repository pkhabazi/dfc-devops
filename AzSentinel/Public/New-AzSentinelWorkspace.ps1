#requires -module @{ModuleName = 'Az.Accounts'; ModuleVersion = '1.5.2'}
#requires -version 6.2

function New-AzSentinelWorkspace {
    <#
    .SYNOPSIS
    Enable Azure Sentinel
    .DESCRIPTION
    This function enables Azure Sentinel on a existing Workspace
    .PARAMETER SubscriptionId
    Enter the subscription ID, if no subscription ID is provided then current AZContext subscription will be used
    .PARAMETER WorkspaceName
    Enter the Workspace name
    .EXAMPLE
    New-AzSentinelWorkspace -WorkspaceName ""
    This example will enable Azure Sentinel for the provided workspace
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $false,
            ParameterSetName = "Sub")]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Location,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Sku = "PerGB2018",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$RetentionInDays = 90
    )
    begin {
        precheck
    }

    process {
        switch ($PsCmdlet.ParameterSetName) {
            Sub {
                $arguments = @{
                    WorkspaceName  = $WorkspaceName
                    SubscriptionId = $SubscriptionId
                }
            }
            default {
                $arguments = @{
                    WorkspaceName = $WorkspaceName
                }
            }
        }

        try {
            $workspaceResult = Get-AzSentinelWorkspace @arguments -ErrorAction Stop
        }
        catch {
            Write-Error $_.Exception.Message
            break
        }

        if ($workspaceResult.properties.provisioningState -ne 'Succeeded') {
            Write-Error "Workspace $WorkspaceName is currently in $($workspaceResult.properties.provisioningState) status, setup canceled"
        }
        elseif ($workspaceResult.properties.provisioningState -eq 'Succeeded') {
            Write-Host "Azure Sentinel already activated"
        }
        else {

            <#
                test if log analytics workspace exists, else create one
            #>

            $lawWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue
            if ($lawWorkspace) {
                Write-Verbose "Log Analytics workspace already exists"
            } else {
                Write-Verbose "start creation workspace"
                try {
                    New-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -Location $Location -Sku $Sku -RetentionInDays $RetentionInDays -ErrorAction Stop
                    Write-Verbose "BAM LAW is screated"
                }
                catch {
                    Write-Verbose $_
                    Write-Error $_.Exception.Message
                    break
                }
            }

            <#
            Testing to see if OperationsManagement resource provider is enabled on subscription
            #>
            $operationsManagementProvider = Get-AzSentinelResourceProvider -NameSpace "OperationsManagement"
            if ($operationsManagementProvider.registrationState -ne 'Registered') {
                Write-Verbose "Resource provider 'Microsoft.OperationsManagement' is not registered, registering"
                New-AzSentinelWorkspaceResourceProvider -NameSpace 'OperationsManagement'
            }
            <#
            Testing to see if SecurityInsights resource provider is enabled on subscription
            #>
            $securityInsightsProvider = Get-AzSentinelResourceProvider -NameSpace 'SecurityInsights'
            if ($securityInsightsProvider.registrationState -ne 'Registered') {
                Write-Warning "Resource provider 'Microsoft.SecurityInsights' is not registered"
                New-AzSentinelWorkspaceResourceProvider -NameSpace 'SecurityInsights'
            }

            $body = @{
                'id'         = ''
                'etag'       = ''
                'name'       = ''
                'type'       = ''
                'location'   = $workspaceResult.location
                'properties' = @{
                    'workspaceResourceId' = $workspaceResult.id
                }
                'plan'       = @{
                    'name'          = 'SecurityInsights($workspace)'
                    'publisher'     = 'Microsoft'
                    'product'       = 'OMSGallery/SecurityInsights'
                    'promotionCode' = ''
                }
            }

            $uri = "$(($Script:baseUri).Split('microsoft.operationalinsights')[0])Microsoft.OperationsManagement/solutions/SecurityInsights($WorkspaceName)?api-version=2015-11-01-preview"

            try {
                $result = Invoke-RestMethod -Uri $uri -Method Put -Headers $script:authHeader -Body ($body | ConvertTo-Json)
                return $result
            }
            catch {
                Write-Verbose $_
                Write-Error $_.Exception.Message
                break
            }
        }
    }
}
