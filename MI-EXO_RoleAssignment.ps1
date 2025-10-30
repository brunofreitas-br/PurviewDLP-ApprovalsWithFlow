# ====== Your Env Data ======
$ClientId     = '<APPLICATION_ID_MI>'
$ServiceId    = '<OBJECT_ID_MI>' 
$RoleName     = 'App-QuarantineOps' 
$AssignName   = 'MI-QuarantineRelease-Assignment'

# ====== Connect to EXO with an admin account that can manage RBAC ======
Connect-ExchangeOnline

# 1) Check if the Service Principal already exists in EXO
$sp = $null
try {
  # Searches for AppId (clientId)
  $sp = Get-ServicePrincipal -AppId $ClientId -ErrorAction SilentlyContinue
} catch {}

if (-not $sp) {
  Write-Host "Service principal with AppId $ClientId not found in EXO. Creating..."

  # 2) Cria o Service Principal no EXO (registre seu app no RBAC do Exchange Online)
  # 2) Creates the Service Principal in EXO (register your app in Exchange Online RBAC)
  #    If you know the ObjectId (principalId) of the MI, pass it in -ServiceId (helps to link correctly).
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

# 4) Check if there is already an assignment for this App
$existing = Get-ManagementRoleAssignment -Role $RoleName -ErrorAction SilentlyContinue |
            Where-Object { $_.AppId -eq $ClientId }

if (-not $existing) {
  Write-Host "Creating assignment of role '$RoleName' for AppId $ClientId ..."
  New-ManagementRoleAssignment -App $ClientId -Role $RoleName -Name $AssignName
  Write-Host "Assignment created."
} else {
  Write-Host "Assignment already exists for this AppId on role '$RoleName': $($existing.Name)"
}

# (Optional) Show what was set up
Get-ManagementRoleAssignment -Role $RoleName | ft Name,AppId,Role,RoleAssigneeType -Auto
