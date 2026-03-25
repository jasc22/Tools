<#
.SYNOPSIS
    Comprehensive Entra ID Service Principal enumeration using Microsoft Graph PowerShell SDK.

.DESCRIPTION
    Enumerates all properties, owners, credentials, permissions, role assignments,
    group memberships, assigned users/groups, and sign-in activity for a given SPN.

.PARAMETER DisplayName
    The display name of the target Service Principal.

.PARAMETER AppId
    The Application (client) ID of the target Service Principal.

.PARAMETER ObjectId
    The Object ID of the target Service Principal.

.EXAMPLE
    .\Enumerate-ServicePrincipal.ps1 -DisplayName "MyApp"
    .\Enumerate-ServicePrincipal.ps1 -AppId "00000000-0000-0000-0000-000000000000"
    .\Enumerate-ServicePrincipal.ps1 -ObjectId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.NOTES
    Required modules:
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
        Install-Module Microsoft.Graph.Applications -Scope CurrentUser
        Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
        Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [string]$AppId,

    [Parameter(Mandatory = $false)]
    [string]$ObjectId
)

# ============================================================
# VALIDATION
# ============================================================
if (-not $DisplayName -and -not $AppId -and -not $ObjectId) {
    Write-Error "You must provide at least one of: -DisplayName, -AppId, or -ObjectId"
    exit 1
}

# ============================================================
# MODULE IMPORTS
# ============================================================
$requiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Applications",
    "Microsoft.Graph.Identity.DirectoryManagement",
    "Microsoft.Graph.Identity.SignIns"
)

foreach ($mod in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Warning "Module '$mod' not found. Installing..."
        Install-Module $mod -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $mod -ErrorAction Stop
}

# ============================================================
# CONNECT TO GRAPH
# ============================================================
$scopes = @(
    "Application.Read.All",
    "Directory.Read.All",
    "AuditLog.Read.All"
)

Write-Host "`n[*] Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes $scopes -ErrorAction Stop
Write-Host "[+] Connected.`n" -ForegroundColor Green

# ============================================================
# RESOLVE THE SERVICE PRINCIPAL
# ============================================================
Write-Host "[*] Resolving Service Principal..." -ForegroundColor Yellow

if ($ObjectId) {
    $spn = Get-MgServicePrincipal -ServicePrincipalId $ObjectId -ErrorAction Stop
} elseif ($AppId) {
    $spn = Get-MgServicePrincipal -Filter "appId eq '$AppId'" -ErrorAction Stop
} else {
    $spn = Get-MgServicePrincipal -Filter "displayName eq '$DisplayName'" -ErrorAction Stop
}

if (-not $spn) {
    Write-Error "Service Principal not found."
    exit 1
}

if ($spn -is [array]) {
    Write-Warning "Multiple SPNs found. Using the first result: $($spn[0].DisplayName)"
    $spn = $spn[0]
}

Write-Host "[+] Found: $($spn.DisplayName) ($($spn.Id))`n" -ForegroundColor Green

# ============================================================
# HELPER FUNCTION
# ============================================================
function Resolve-DirectoryObject {
    param([string]$Id)
    try {
        $obj = Get-MgDirectoryObject -DirectoryObjectId $Id -ErrorAction Stop
        return [PSCustomObject]@{
            DisplayName = $obj.AdditionalProperties.displayName
            UPN         = $obj.AdditionalProperties.userPrincipalName
            ObjectType  = ($obj.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', '')
            Id          = $obj.Id
        }
    } catch {
        return [PSCustomObject]@{
            DisplayName = "Unresolvable"
            UPN         = $null
            ObjectType  = "Unknown"
            Id          = $Id
        }
    }
}

# ============================================================
# 1. CORE PROPERTIES
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  CORE PROPERTIES" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$spn | Select-Object `
    DisplayName, AppId, Id, ServicePrincipalType,
    AccountEnabled, SignInAudience, AppOwnerOrganizationId,
    PreferredSingleSignOnMode, LoginUrl, LogoutUrl,
    NotificationEmailAddresses, Tags,
    CreatedDateTime | Format-List

Write-Host "--- Reply URLs ---" -ForegroundColor DarkGray
if ($spn.ReplyUrls) { $spn.ReplyUrls | ForEach-Object { Write-Host "  $_" } }
else { Write-Host "  (none)" }

Write-Host "`n--- Service Principal Names ---" -ForegroundColor DarkGray
if ($spn.ServicePrincipalNames) { $spn.ServicePrincipalNames | ForEach-Object { Write-Host "  $_" } }
else { Write-Host "  (none)" }

# ============================================================
# 2. SPN OWNERS
# ============================================================
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "  SERVICE PRINCIPAL OWNERS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$spnOwners = Get-MgServicePrincipalOwner -ServicePrincipalId $spn.Id -All -ErrorAction SilentlyContinue
if ($spnOwners) {
    $spnOwners | ForEach-Object { Resolve-DirectoryObject -Id $_.Id } | Format-Table -AutoSize
} else {
    Write-Host "  (no owners assigned)`n"
}

# ============================================================
# 3. LINKED APP REGISTRATION
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  LINKED APP REGISTRATION" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

try {
    $app = Get-MgApplication -Filter "appId eq '$($spn.AppId)'" -ErrorAction Stop

    if ($app) {
        $app | Select-Object DisplayName, Id, AppId, SignInAudience, CreatedDateTime | Format-List

        # App Registration Owners
        Write-Host "--- App Registration Owners ---" -ForegroundColor DarkGray
        $appOwners = Get-MgApplicationOwner -ApplicationId $app.Id -All -ErrorAction SilentlyContinue
        if ($appOwners) {
            $appOwners | ForEach-Object { Resolve-DirectoryObject -Id $_.Id } | Format-Table -AutoSize
        } else {
            Write-Host "  (no owners)`n"
        }

        # Secrets
        Write-Host "--- Password Credentials (Secrets) ---" -ForegroundColor DarkGray
        if ($app.PasswordCredentials) {
            $app.PasswordCredentials | Select-Object `
                DisplayName, KeyId, StartDateTime, EndDateTime,
                @{N='Status'; E={ if ($_.EndDateTime -gt (Get-Date)) { 'ACTIVE' } else { 'EXPIRED' } }} |
                Format-Table -AutoSize
        } else {
            Write-Host "  (none)`n"
        }

        # Certificates
        Write-Host "--- Key Credentials (Certificates) ---" -ForegroundColor DarkGray
        if ($app.KeyCredentials) {
            $app.KeyCredentials | Select-Object `
                DisplayName, KeyId, Type, Usage, StartDateTime, EndDateTime,
                @{N='Status'; E={ if ($_.EndDateTime -gt (Get-Date)) { 'ACTIVE' } else { 'EXPIRED' } }} |
                Format-Table -AutoSize
        } else {
            Write-Host "  (none)`n"
        }
    }
} catch {
    Write-Host "  No linked app registration found (managed identity or external SPN)`n" -ForegroundColor Yellow
}

# ============================================================
# 4. GROUP MEMBERSHIPS
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  DIRECT GROUP MEMBERSHIPS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$memberships = Get-MgServicePrincipalMemberOf -ServicePrincipalId $spn.Id -All -ErrorAction SilentlyContinue
if ($memberships) {
    $memberships | ForEach-Object { Resolve-DirectoryObject -Id $_.Id } | Format-Table -AutoSize
} else {
    Write-Host "  (none)`n"
}

# Transitive
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  TRANSITIVE MEMBERSHIPS (including nested)" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$transitive = Get-MgServicePrincipalTransitiveMemberOf -ServicePrincipalId $spn.Id -All -ErrorAction SilentlyContinue
if ($transitive) {
    $transitive | ForEach-Object { Resolve-DirectoryObject -Id $_.Id } | Format-Table -AutoSize
} else {
    Write-Host "  (none)`n"
}

# ============================================================
# 5. ENTRA ID DIRECTORY ROLE ASSIGNMENTS
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  DIRECTORY ROLE ASSIGNMENTS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

try {
    $roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($spn.Id)'" -All -ErrorAction Stop
    if ($roleAssignments) {
        $roleAssignments | ForEach-Object {
            $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $_.RoleDefinitionId
            [PSCustomObject]@{
                RoleName       = $roleDef.DisplayName
                IsBuiltIn      = $roleDef.IsBuiltIn
                RoleId         = $_.RoleDefinitionId
                DirectoryScope = $_.DirectoryScopeId
            }
        } | Format-Table -AutoSize
    } else {
        Write-Host "  (no directory roles assigned)`n"
    }
} catch {
    Write-Host "  Unable to query directory roles: $($_.Exception.Message)`n" -ForegroundColor Yellow
}

# ============================================================
# 6. DELEGATED PERMISSIONS (OAuth2 Grants)
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  DELEGATED PERMISSIONS (OAuth2 Grants)" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$oauth2Grants = Get-MgServicePrincipalOAuth2PermissionGrant -ServicePrincipalId $spn.Id -All -ErrorAction SilentlyContinue
if ($oauth2Grants) {
    $oauth2Grants | ForEach-Object {
        $resource = Get-MgServicePrincipal -ServicePrincipalId $_.ResourceId -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Resource    = $resource.DisplayName
            Scopes      = $_.Scope
            ConsentType = $_.ConsentType
            PrincipalId = $_.PrincipalId
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "  (no delegated permissions)`n"
}

# ============================================================
# 7. APPLICATION PERMISSIONS (App Role Assignments)
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  APPLICATION PERMISSIONS (App Role Assignments)" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$appRoles = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $spn.Id -All -ErrorAction SilentlyContinue
if ($appRoles) {
    $appRoles | ForEach-Object {
        $resource = Get-MgServicePrincipal -ServicePrincipalId $_.ResourceId -ErrorAction SilentlyContinue
        $matchedRole = $resource.AppRoles | Where-Object { $_.Id -eq $_.AppRoleId }
        [PSCustomObject]@{
            Resource    = $resource.DisplayName
            Permission  = $matchedRole.Value
            Description = $matchedRole.Description
            RoleId      = $_.AppRoleId
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "  (no application permissions)`n"
}

# ============================================================
# 8. USERS & GROUPS ASSIGNED TO THE SPN
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  ASSIGNED USERS & GROUPS (Enterprise App)" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$assignedTo = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $spn.Id -All -ErrorAction SilentlyContinue
if ($assignedTo) {
    $assignedTo | Select-Object `
        PrincipalDisplayName, PrincipalType, PrincipalId,
        AppRoleId, CreatedDateTime | Format-Table -AutoSize
} else {
    Write-Host "  (no users or groups assigned)`n"
}

# ============================================================
# 9. SIGN-IN ACTIVITY
# ============================================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  RECENT SIGN-IN ACTIVITY (last 10)" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

try {
    $signIns = Get-MgAuditLogSignIn -Filter "appId eq '$($spn.AppId)'" -Top 10 -ErrorAction Stop
    if ($signIns) {
        $signIns | Select-Object `
            CreatedDateTime, UserPrincipalName, AppDisplayName,
            IpAddress,
            @{N='StatusCode'; E={ $_.Status.ErrorCode }},
            @{N='FailureReason'; E={ $_.Status.FailureReason }},
            ConditionalAccessStatus | Format-Table -AutoSize
    } else {
        Write-Host "  (no recent sign-ins found)`n"
    }
} catch {
    Write-Host "  Unable to retrieve sign-in logs (requires AuditLog.Read.All and P1/P2 license)`n" -ForegroundColor Yellow
}

# ============================================================
# SUMMARY
# ============================================================
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "  ENUMERATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "  Target:       $($spn.DisplayName)"
Write-Host "  AppId:        $($spn.AppId)"
Write-Host "  ObjectId:     $($spn.Id)"
Write-Host "  Enabled:      $($spn.AccountEnabled)"
Write-Host "  SPN Type:     $($spn.ServicePrincipalType)"
Write-Host "  Owner Count:  $(if ($spnOwners) { $spnOwners.Count } else { 0 })"
Write-Host "  Group Count:  $(if ($memberships) { $memberships.Count } else { 0 })"
Write-Host ""
