##########################################################################################################
# Update Workbook Templates & Dashboards
##########################################################################################################

<#
    PreReq
    install-module az.portal
#>

##########################################################################################################
# Variables
##########################################################################################################

    $DeleteExistingWorkbooksBeforeDeployment     = $false
    $DeleteExistingDashboardsBeforeDeployment    = $false
    $DataPath                                    = "$($Env:OneDrive)\SCRIPTS_REPOSITORY\SCRIPTS-AUTOMATION\TARGETS_UPDATE_MANAGEMENT"
    $TargetData                                  = Import-csv "$($DataPath)\Targets_Update_Management.csv" -Delimiter ";"
    $TargetData                                  = $TargetData | Where-Object { $_.AADAppId -ne "" }
    $LookFor_Srv_Cloud_ResourceId_Array          = $TargetData.LAWS_Srv_ResourceId
    $LookFor_WS_Client_ResourceId_Array          = $TargetData.LAWS_Client_ResourceId
    $LookFor_Company_Array                       = $TargetData.Target

    $WorkBook_Repository_Path                    = "$($Env:OneDrive)\SCRIPTS_REPOSITORY\SCRIPTS-AUTOMATION\AZURE_WORKBOOKS_LATEST_RELEASE\WORKBOOKS_LATEST_RELEASE"
    $Dashboard_Repository_Path                   = "$($Env:OneDrive)\SCRIPTS_REPOSITORY\SCRIPTS-AUTOMATION\AZURE_DASHBOARDS_LATEST_RELEASE"
    $Deployment_Template_Header_Path             = "$($Env:OneDrive)\SCRIPTS_REPOSITORY\SCRIPTS-AUTOMATION\AZURE_WORKBOOKS_LATEST_RELEASE\DEPLOYMENT_TEMPLATE_HEADERS"
    $Deployment_Template_Header_Begin_File       = $Deployment_Template_Header_Path + "\" + "DeploymentTemplate_Begin.txt"
    $Deployment_Template_Header_End_File         = $Deployment_Template_Header_Path + "\" + "DeploymentTemplate_End.txt"


##########################################################################################################
# Main Program
##########################################################################################################
    ForEach ($Entry in $TargetData)
        {
            $Target                        = $Entry.Target
            $LAWS_Srv_ResourceId           = $Entry.LAWS_Srv_ResourceId
            $LAWS_Client_ResourceId        = $Entry.LAWS_Client_ResourceId
            $AzSubscription                = $Entry.AzSubscription
            $AzResourceGroup               = $Entry.AzResourceGroup
            $AzLocation                    = $Entry.AzLocation
            $AzTenant                      = $Entry.AzTenant
            $Exclude_Workbooks             = $Entry.Exclude_Workbooks
            $Exclude_Dashboards            = $Entry.Exclude_Dashboards
            $AADAppId                      = $Entry.AADAppId
            $AADAppName                    = $Entry.AADAppName
            $SecretValue                   = $Entry.SecretValue
            $SecretExpire_MMDDYYYY         = $Entry.SecretExpire_MMDDYYYY
            $SecretName                    = $Entry.SecretValue
            $WorkBook_Destination_Path     = "C:\TMP" + "\" + $Target + "\WORKBOOKS"
            $Dashboard_Destination_Path    = "C:\TMP" + "\" + $Target + "\DASHBOARD"


        ##########################################################################################################
        # Discount existing sessions
        ##########################################################################################################
            $Result = Get-AzContext | Disconnect-AzAccount

        ##########################################################################################################
        # Connect
        ##########################################################################################################
            $SecretSecure = ConvertTo-SecureString -String $SecretValue -AsPlainText -Force
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AADAppId, $SecretSecure
            
            Write-Output "Connecting to $($Target) Azure tenant .... Please Wait !"
            Connect-AzAccount -ServicePrincipal -TenantId $AzTenant -Credential $Credential -WarningAction SilentlyContinue
            $Context = Set-AzContext -Subscription $AzSubscription -Tenant $AzTenant


        ##########################################################################################################
        # Source
        ##########################################################################################################

            $Replace_Srv_Cloud_To_ResourceId             = $LAWS_Srv_ResourceId
            $Replace_Srv_Cloud_To_SubId                  = $LAWS_Srv_ResourceId.split("/")[2]
            $Replace_Srv_Cloud_To_RGName                 = $LAWS_Srv_ResourceId.split("/")[4]
            $Replace_Ws_Client_To_ResourceId             = $LAWS_Client_ResourceId
            $Replace_Ws_Client_To_SubId                  = $LAWS_Client_ResourceId.split("/")[2]
            $Replace_Ws_Client_To_RGName                 = $LAWS_Client_ResourceId.split("/")[4]
            $Replace_Company_To                          = $Target


        ##########################################################################################################
        # WorkBook Management | Main Program
        ##########################################################################################################

            Write-Output "Creating Workbook Destination Path $($WorkBook_Destination_Path)"
                MD $WorkBook_Destination_Path -ErrorAction SilentlyContinue

            Write-Output "Cleaning up existing files in WorkBook_Destination_Path"
                Get-ChildItem -Path $WorkBook_Destination_Path | Remove-Item -Force

            Write-Output "Building array of source workbook files"
                $Files_Temp = Get-ChildItem -Path $WorkBook_Repository_Path | %{$_.FullName}

            Write-Output "Making exclusions"
                $Files = @()
                ForEach ($File in $Files_Temp)
                    {
                        $Files += $File | Where-Object { ($_ -notlike $Exclude_Workbooks) }
                    }

            Write-Output "Building customer file, based on repository and deployment files"
            ForEach ($File in $Files)
                {
                    $TargetFile = $WorkBook_Destination_Path + "\" + (Get-Item $File).Basename + ".json"

                    $FileContent = (Get-content $Deployment_Template_Header_Begin_File) + `
                                   (Get-content $File) + `
                                   (Get-content $Deployment_Template_Header_End_File)

                    Write-Output "Writing modified file"
                    Get-ChildItem -Path $TargetFile -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    Add-Content $TargetFile -Value $FileContent -Encoding UTF8 -Force
                }

            Write-Output "Building array of files to replace"
                $Files = Get-ChildItem -Path $WorkBook_Destination_Path | %{$_.FullName}

            #-------------------------------------------------------------------------------------------------------
            # SEARCH & REPLACE
            #-------------------------------------------------------------------------------------------------------
            ForEach ($File in $Files)
                {
                    $WorkbookName = (Get-Item $File).Basename
                    $Name = $WorkbookName
                    $Category = ($Target.replace(" ","_")) + " IT Operation Security Templates - Managed"

                    Write-Output ""
                    Write-Output "Processing $($File)"
                    $FileContent = Get-Content $File -Encoding UTF8

                    ForEach ($SourceEntry in $LookFor_Srv_Cloud_ResourceId_Array)
                        {
                            $FileContent = $FileContent -Replace ("$($SourceEntry)","$($Replace_Srv_Cloud_To_ResourceId)")
                        }

                    ForEach ($SourceEntry in $LookFor_WS_Client_ResourceId_Array)
                        {
                            $FileContent = $FileContent -Replace ("$($SourceEntry)","$($Replace_Ws_Client_To_ResourceId)")
                        }

                    ForEach ($SourceEntry in $LookFor_Company_Array)
                        {
                            $FileContent = $FileContent -Replace ("$($SourceEntry)","$($Replace_Company_To)")
                        }

                    $FileContent = $FileContent -Replace ("TEMPLATE_NAME","$($Name)")
                    $FileContent = $FileContent -Replace ("TEMPLATE_CATEGORY","$($Category)")
 
                    $FileContent = $FileContent -Replace ("SUB_TO_REPLACE","$($AzSubscription)")
                    $FileContent = $FileContent -Replace ("RG_TO_REPLACE","$($AzResourceGroup)")
                    $FileContent = $FileContent -Replace ("INSERT LOCATION","$($AzLocation)")

                    Write-Output "Writing modified file"
                    Get-ChildItem -Path $File | Remove-Item -Force
                    Add-Content $File -Value $FileContent -Encoding UTF8 -Force
                }

                #-------------------------------------------------------------------------------------------------------
                # DELETE ALL WORKBOOKS IN RESOURCE GROUP
                #-------------------------------------------------------------------------------------------------------
                If ($DeleteExistingWorkbooksBeforeDeployment -eq $true)
                    {
                        Write-output ""
                        Write-Output "Removing existing managed workbooks ... Please Wait !"
                        $AzContext = Set-AzContext -Subscription $AzSubscription -Tenant $AzTenant
                        $RGCheck = Get-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation -ErrorAction SilentlyContinue
                            If ($RGCheck -eq $null)
                                {  
                                    $Result = New-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation
                                }
        
                        $Resources = Get-AzResource -ResourceGroupName $AzResourceGroup -ResourceType "microsoft.insights/workbooktemplates" | Remove-AzResource -force
                    }


                #-------------------------------------------------------------------------------------------------------
                # DEPLOYMENT
                #-------------------------------------------------------------------------------------------------------
                $AzContext = Set-AzContext -Subscription $AzSubscription -Tenant $AzTenant
                $RGCheck = Get-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation -ErrorAction SilentlyContinue
                    If ($RGCheck -eq $null)
                        {  
                            $Result = New-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation
                        }

                ForEach ($File in $Files)
                    {
                        #-------------------------------------------------------------------------------------------------------
                        # DEPLOYMENT TO AZURE - if files are OK
                        #-------------------------------------------------------------------------------------------------------
                            $Found_SRV_Cloud = $True
                            If ($Found_SRV_Cloud -eq $true)
                                {
                                    $Deployment_Suffix  = Get-Random -Maximum 1000
                                    $WorkbookName       = (Get-Item $File).Basename
                                    $DeploymentName     = ($WorkbookName.replace(" ","_")) + $Deployment_Suffix

                                    Write-Output ""
                                    Write-Output "Deploying Azure Workbook to $($Target) Azure as Job ...."
                                    Write-Output ""
                                    Write-Output "  Azure subscription               [ $($AzSubscription) ]"
                                    Write-Output "  Azure resource group             [ $($AzResourceGroup) ]"
                                    Write-Output ""
                                    Write-Output "  Workbook Name                    [ $($WorkbookName) ]"
                                    Write-Output ""
                                    Write-Output "  Template file"
                                    Write-Output "  $($TemplateFile)"

                                    $Deploy = New-AzResourceGroupDeployment `
                                    -Name $DeploymentName `
                                    -ResourceGroupName $AzResourceGroup `
                                    -TemplateFile $File  `
                                    -AsJob
                                }
                    }

        ##########################################################################################################
        # Dashboard Management | Main Program
        ##########################################################################################################

            Write-Output "Creating Dashboard Destination Path $($Dashboard_Destination_Path)"
                MD $Dashboard_Destination_Path -ErrorAction SilentlyContinue

            Write-Output "Cleaning up existing files in WorkBook_Destination_Path"
                Get-ChildItem -Path $Dashboard_Destination_Path | Remove-Item -Force

            Write-Output "Building array of source workbook files"
                $Files_Temp = Get-ChildItem -Path $Dashboard_Repository_Path | %{$_.FullName}

            Write-Output "Making exclusions"
                $Files = @()
                ForEach ($File in $Files_Temp)
                    {
                        $Files += $File | Where-Object { ($_ -notlike $Exclude_Workbooks) }
                    }
            
            Write-Output "Copying dashboard files"
                Copy-Item -Path $Files -Destination $Dashboard_Destination_Path -Force

            Write-Output "Building array of files to replace"
                $Files = Get-ChildItem -Path $Dashboard_Destination_Path | %{$_.FullName}


            #-------------------------------------------------------------------------------------------------------
            # SEARCH & REPLACE
            #-------------------------------------------------------------------------------------------------------
            ForEach ($File in $Files)
                {
                    Write-Output ""
                    Write-Output "Processing $($File)"
                    $FileContent = Get-Content $File -Encoding UTF8

                    # Resource Id
                        ForEach ($SourceEntry in $LookFor_Srv_Cloud_ResourceId_Array)
                            {
                                $FileContent = $FileContent -Replace ("$($SourceEntry)","$($Replace_Srv_Cloud_To_ResourceId)")
                            }

                        ForEach ($SourceEntry in $LookFor_WS_Client_ResourceId_Array)
                            {
                                $FileContent = $FileContent -Replace ("$($SourceEntry)","$($Replace_Ws_Client_To_ResourceId)")
                            }

                        ForEach ($SourceEntry in $LookFor_Company_Array)
                            {
                                $FileContent = $FileContent -Replace ("$($SourceEntry)","$($Replace_Company_To)")
                            }

                    # Arm templates - srv
                        ForEach ($SourceEntry in $LookFor_Srv_Cloud_ResourceId_Array)
                            {
                                $LookForSubId  = ($SourceEntry.Split("/"))[2]
                                $LookForRgName = ($SourceEntry.Split("/"))[4]

                                $FileContent = $FileContent -Replace ("$($LookForSubId)","$($Replace_Srv_Cloud_To_SubId)")
                            }

                    # Arm templates - ws
                        ForEach ($SourceEntry in $LookFor_WS_Client_ResourceId_Array)
                            {
                                $LookForSubId  = ($SourceEntry.Split("/"))[2]
                                $LookForRgName = ($SourceEntry.Split("/"))[4]

                                $FileContent = $FileContent -Replace ("$($LookForSubId)","$($Replace_Ws_Client_To_SubId)")
                            }

                    $FileContent = $FileContent -Replace ("SUB_TO_REPLACE","$($AzSubscription)")
                    $FileContent = $FileContent -Replace ("RG_TO_REPLACE","$($AzResourceGroup)")
                    $FileContent = $FileContent -Replace ("INSERT LOCATION","$($AzLocation)")


                    Write-Output "Writing modified file"
                    Get-ChildItem -Path $File | Remove-Item -Force
                    Add-Content $File -Value $FileContent -Encoding UTF8 -Force
                }

                #-------------------------------------------------------------------------------------------------------
                # DELETE ALL DASHBOARDS IN RESOURCE GROUP
                #-------------------------------------------------------------------------------------------------------
                If ($DeleteExistingDashboardsBeforeDeployment -eq $true)
                    {
                        Write-output ""
                        Write-Output "Removing existing managed dashboards ... Please Wait !"
                        $AzContext = Set-AzContext -Subscription $AzSubscription -Tenant $AzTenant
                        $RGCheck = Get-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation -ErrorAction SilentlyContinue
                            If ($RGCheck -eq $null)
                                {  
                                    $Result = New-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation
                                }
        
                        $Resources = Get-AzResource -ResourceGroupName $AzResourceGroup -ResourceType "Microsoft.Portal/dashboards" | Remove-AzResource -force
                    }

                #-------------------------------------------------------------------------------------------------------
                # DEPLOYMENT
                #-------------------------------------------------------------------------------------------------------
                ForEach ($File in $Files)
                    {
                        #-------------------------------------------------------------------------------------------------------
                        # DEPLOYMENT TO AZURE - if files are OK
                        #-------------------------------------------------------------------------------------------------------
                            $Deployment_Suffix  = Get-Random -Maximum 1000
                            $DashboardName      = (Get-Item $File).Basename
                            $DashboardName      = ($DashboardName.replace("-","_"))
                            $DashboardName      = ($DashboardName.replace(" ","_"))

                            $AzContext = Set-AzContext -Subscription $AzSubscription -Tenant $AzTenant

                            Write-Output ""
                            Write-Output "Deploying Azure Dashboard to $($Target) Azure .... "
                            Write-Output ""
                            Write-Output "  Azure subscription               [ $($AzSubscription) ]"
                            Write-Output "  Azure resource group             [ $($AzResourceGroup) ]"
                            Write-Output ""
                            Write-Output "  Dashboard Name                   [ $($DashboardName) ]"
                            Write-Output ""
                            Write-Output "  Template file"
                            Write-Output "  $($TemplateFile)"

                            $Deploy = New-AzPortalDashboard `
                            -DashboardPath $File `
                            -ResourceGroupName $AzResourceGroup `
                            -DashboardName $DashboardName

                            $Deploy = Set-AzPortalDashboard `
                            -DashboardPath $File `
                            -ResourceGroupName $AzResourceGroup `
                            -DashboardName $DashboardName
                    }
    pause
    }

