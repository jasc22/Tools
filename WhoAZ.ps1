<# Install and import AzureAD module if not already installed
if (-not (Get-Module -Name AzureAD -ErrorAction SilentlyContinue)) {
    Install-Module -Name AzureAD -Scope CurrentUser -Force -AllowClobber
    Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber
}#>

#Import-Module AzureAD

# Prompt for Azure AD credentials
#$credential = Get-Credential -Message "Enter your Azure AD credentials"

# Connect using Azure AD
#Connect-AzureAD -Credential $credential | Out-Null

# Connect using Az with Username and Password
#Connect-AzAccount -Credential $credential | Out-Null

# Input user principal name
$userPrincipalName = Read-Host "Enter User Principal Name (e.g., user@contoso.com)"

# Get user object
$user = Get-AzureADUser -Filter "UserPrincipalName eq '$userPrincipalName'"

Write-Host "`nTarget:" $($user.UserPrincipalName)
Write-Host "`User ObjectId: $($user.objectId)`n"


if ($user -eq $null) {
    Write-Host "User not found."
} else {
    # Get group memberships
    $groupMemberships = Get-AzureADUserMembership -ObjectId $($user.ObjectId)

    Write-Host "`n----------------"
    Write-Host "Group Memberships"
    Write-Host "-----------------`n"
    
if ($groupMemberships) {
    foreach ($group in $groupMemberships) {
        Write-Host "Group Name: $($group.DisplayName)"
        Write-Host "Group Description: $($group.Membership)"
        Write-Host "Group ObjectId: $($group.ObjectId)`n"
    }
} else {
    Write-Host "User $($User.UserPrincipalName) is not a member of any groups."
}

    # Get Azure AD role assignments
    Write-Host "`n---------------"
    Write-Host "Assigned Roles"
    Write-Host "----------------`n"
    if ($user) {
    $userId = $user.ObjectId
    Get-AzureADDirectoryRole | ForEach-Object {
        $roleName = $_.DisplayName
        $roleMembers = Get-AzureADDirectoryRoleMember -ObjectId $_.ObjectId -ErrorAction SilentlyContinue
        $userRole = $roleMembers | Where-Object { $_.ObjectId -eq $userId }
        if ($userRole) {
            Write-Host "Azure AD Role Name: $roleName"
            Write-Host "Azure ADObject Type: $($userRole.ObjectType)"
            Write-Host ""
        }
    }
} else {
    Write-Host "User with UserPrincipalName '$userPrincipalName' not found."
}

    # Get administrative unit memberships
    $adminUnitMemberships = Get-AzureADMSAdministrativeUnit | ForEach-Object { $AUDisplayName=$_.DisplayName; $AUDesc=$_.Description; Get-AzureADMSScopedRoleMembership -Id $_.Id | ForEach-Object { $DisplayNameR=$_.RoleMemberInfo.DisplayName; $IdR=$_.RoleMemberInfo.Id; Get-AzureADDirectoryRole -ObjectId $_.RoleId | ForEach-Object { "$($AUDisplayName),$($AUDesc),$($DisplayNameR),$($IdR),$ADDirRole=$($_.DisplayName),ADDirDesc=$($_.Description)" } } }

    Write-Host "`n----------------------------------"
    Write-Host "Administrative Unit Memberships"
    Write-Host "----------------------------------`n"
    $adminUnitMemberships | ForEach-Object {
        Write-Host "Member of: $($AUDisplayName)"
        Write-Host "AU Description: $($AUDesc)"
        Write-Host "Scoped Role: $($ADDirRole)"
        Write-Host "Scoped Role Description: $($ADDirDesc)"
        Write-Host "Scope is assigned to $($DisplayNameR)"
    }

    # Get Azure resources
    $resources = Get-AzResource
    Write-Host "`n------------------------------------------------------------------------------------------"
    Write-Host "$($User.UserPrincipalName) has access to the following Azure resources"
    Write-Host "--------------------------------------------------------------------------------------------`n"

    #Iterate over each resource for the current account and print
    foreach ($resource in $resources) {
        Write-Host "Name: "$($resource.Name)
        Write-Host "Resource Group: "$($resource.ResourceGroupName)
        Write-Host "Resource Id: "$($resource.ResourceId)`n
    }
}
