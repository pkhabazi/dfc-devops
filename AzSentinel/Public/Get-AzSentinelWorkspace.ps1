#requires -module @{ModuleName = 'Az.Accounts'; ModuleVersion = '1.5.2'}
#requires -version 6.2

function Get-AzSentinelWorkspace {
    <#
    .SYNOPSIS
    Get Azure Sentinel Incident
    .DESCRIPTION
    With this function you can get a list of open incidents from Azure Sentinel.
    You can can also filter to Incident with speciefiek case namber or Case name
    .PARAMETER SubscriptionId
    Enter the subscription ID, if no subscription ID is provided then current AZContext subscription will be used
    .PARAMETER WorkspaceName
    Enter the Workspace name
    .EXAMPLE
    Get-AzSentinelWorkspace-WorkspaceName ""
    Get Azure sentinel Workspace
    #>

    param (
        [Parameter(Mandatory = $false,
            ParameterSetName = "Sub")]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceName
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
            $workspace = Get-LogAnalyticWorkspace @arguments -FullObject -ErrorAction Stop
            Write-Verbose "'$WorkspaceName' exists"
        }
        catch {
            Write-Error $_.Exception.Message
            break
        }

        if ($workspace) {
            $uri = ($script:baseUri).Split('microsoft.operationalinsights')[0] + "Microsoft.OperationsManagement/solutions/SecurityInsights(nf-pkm-sent-weu-prd)?api-version=2015-11-01-preview"
            Write-Verbose -Message "Using URI: $($uri)"

            try {
                $result = (Invoke-RestMethod -Uri $uri -Method Get -Headers $script:authHeader)
                return $result
            }
            catch {
                Write-Verbose $_
                Write-Error $_.Exception.Message
                break
            }
        }
        else {
            Write-Host "Workspace not found"
            return
        }
    }
}
