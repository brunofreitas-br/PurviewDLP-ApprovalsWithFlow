# ====== Part 1 ======
# Grant App Role Assignment (Exchange.ManageAsApp) to the Managed Identity in Entra ID

Connect-MgGraph -Scopes AppRoleAssignment.ReadWrite.All,Application.Read.All,RoleManagement.ReadWrite.Directory
$MI_ID = '<YOUR-MI-ObjectID>'
# Get the Service Principal for Exchange Online
$exoSp = Get-MgServicePrincipal -Filter "AppId eq '00000002-0000-0ff1-ce00-000000000000'"
# Assign the Exchange.ManageAsApp role
New-MgServicePrincipalAppRoleAssignment `
  -ServicePrincipalId $MI_ID `
  -PrincipalId $MI_ID `
  -ResourceId $exoSp.Id `
  -AppRoleId 'dc50a0fb-09a3-484d-be87-e023b12c6440'

# ====== Part 2 ======
# Create a new, minimal Management Role in Exchange Online

Connect-ExchangeOnline
# If it already exists, this Get-ServicePrincipal will return something
Get-ServicePrincipal -Identity <ManagedIdentity-ClientId> -ErrorAction SilentlyContinue `
  || New-ServicePrincipal -AppId <ManagedIdentity-ClientId> -DisplayName "sp-mi-exo-quarantine"

# Find the parent role that has the 'Release-QuarantineMessage' cmdlet
Get-ManagementRole |
  ForEach-Object {
    Get-ManagementRoleEntry "$($_.Name)\Release-QuarantineMessage" -ErrorAction SilentlyContinue |
      Select-Object @{n='Role';e={$_.Role}}, Name
  } | Where-Object Name -eq 'Release-QuarantineMessage'


# Inherits from the parent role identified above (e.g., "Transport Hygiene")
New-ManagementRole -Name "App-QuarantineOps" -Parent "Transport Hygiene"


# ====== Part 3 ======
# Minimize the new Management Role to only include necessary cmdlets

# ===== Config =====
$RoleName          = 'App-QuarantineOps'
$IncludePreview    = $false  # true to keep Preview-QuarantineMessage
$IncludeExport     = $false  # true to keep Export-QuarantineMessage
$IncludeGetHeaders = $false  # true to keep Get-QuarantineMessageHeader
$WhatIf            = $false  # first run in dry-run mode; then set to $false

# ===== Choose what to keep =====
$keep = @(
  'Get-QuarantineMessage',
  'Release-QuarantineMessage'
)
if ($IncludePreview)    { $keep += 'Preview-QuarantineMessage' }
if ($IncludeExport)     { $keep += 'Export-QuarantineMessage' }
if ($IncludeGetHeaders) { $keep += 'Get-QuarantineMessageHeader' }

Write-Host ">>> Keeping cmdlets:" ($keep -join ', ')

# ===== List current role entries =====
$all = Get-ManagementRoleEntry "$RoleName\*" -ErrorAction Stop
Write-Host "Total entries in role '$RoleName':" $all.Count

# ===== Calculate what to remove =====
$toRemove = $all | Where-Object { $_.Name -notin $keep }

if (-not $toRemove) {
  Write-Host "Nothing to remove. The role is already minimized."
} else {
  Write-Host "Entries to remove ($($toRemove.Count)):"
  $toRemove | Select-Object Name | Sort-Object Name | Format-Table -AutoSize

  foreach ($e in $toRemove) {
    $entryName = "$RoleName\$($e.Name)"
    if ($WhatIf) {
      Write-Host "[WhatIf] Remove-ManagementRoleEntry '$entryName'"
    } else {
      try {
        Remove-ManagementRoleEntry $entryName -Confirm:$false -ErrorAction Stop
        Write-Host "Removed: $entryName"
      } catch {
        Write-Warning "Failed to remove $entryName -> $($_.Exception.Message)"
      }
    }
  }
}

Write-Host ">>> Final review:"
Get-ManagementRoleEntry "$RoleName\*" | Select-Object Name, Role | Sort-Object Name | Format-Table -AutoSize

# ====== Part 4 ======
# Assign the minimal role to the Managed Identity's Service Principal

# ====== Fill in your data ======
$ClientId     = '<APP_ID_MI>'      # Managed Identity CLIENT ID (appId)
$ServiceId    = '<OBJECT_ID_MI>'     # Managed Identity OBJECT ID (principalId) - optional but recommended
$RoleName     = 'App-QuarantineOps'      # your minimalist role that we created
$AssignName   = 'MI-QuarantineRelease-Assignment'    # name of the assignment

# ====== Connect to EXO with an admin account that can manage RBAC ======
Connect-ExchangeOnline

# 1) Check if the Service Principal already exists in EXO
$sp = $null
try {
  # Search by AppId (clientId)
  $sp = Get-ServicePrincipal -AppId $ClientId -ErrorAction SilentlyContinue
} catch {}

if (-not $sp) {
  Write-Host "Service principal with AppId $ClientId not found in EXO. Creating..."

  # 2) Create the Service Principal in EXO (register your app in Exchange Online RBAC)
  #    If you know the MI's ObjectId (principalId), pass it to -ServiceId (helps to link correctly).
  if ($ServiceId -and $ServiceId -match '^[0-9a-fA-F-]{36}$') {
    $sp = New-ServicePrincipal -AppId $ClientId -ServiceId $ServiceId -DisplayName "MI-$ClientId"
  } else {
    $sp = New-ServicePrincipal -AppId $ClientId -DisplayName "MI-$ClientId"
  }

  Write-Host "Service principal created: $($sp.AppId) / $($sp.DisplayName)"
} else {
  Write-Host "Service principal already exists in EXO: $($sp.AppId) / $($sp.DisplayName)"
}

# 3) Ensure the role exists
$role = Get-ManagementRole -Identity $RoleName -ErrorAction Stop

# 4) Check if an assignment already exists for this App
$existing = Get-ManagementRoleAssignment -Role $RoleName -ErrorAction SilentlyContinue |
            Where-Object { $_.AppId -eq $ClientId }

if (-not $existing) {
  Write-Host "Creating role assignment '$RoleName' for AppId $ClientId ..."
  New-ManagementRoleAssignment -App $ClientId -Role $RoleName -Name $AssignName
  Write-Host "Assignment created."
} else {
  Write-Host "Assignment already exists for this AppId in role '$RoleName': $($existing.Name)"
}

# (Optional) Show the result
Get-ManagementRoleAssignment -Role $RoleName | ft Name,AppId,Role,RoleAssigneeType -Auto
