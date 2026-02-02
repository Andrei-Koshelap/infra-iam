#!/usr/bin/env bash
set -euo pipefail
set -x

log() { echo "[bootstrap] $*"; }

# ---- Config ----
LDAP_HOST="${LDAP_HOST:-iam-ad}"
ADMIN_USER="${ADMIN_USER:-Administrator}"
ADMIN_PASS="${ADMIN_PASS:-Admin123!}"

REALM="${REALM:-EXAMPLE.TEST}"

# Build BASE_DN from REALM: EXAMPLE.TEST -> DC=example,DC=test
IFS='.' read -r -a parts <<< "$(echo "$REALM" | tr '[:upper:]' '[:lower:]')"
BASE_DN=""
for p in "${parts[@]}"; do
  [[ -n "$BASE_DN" ]] && BASE_DN="${BASE_DN},"
  BASE_DN="${BASE_DN}DC=${p}"
done

LDAP_URI="ldap://${LDAP_HOST}"

log "Using REALM=${REALM}"
log "BASE_DN=${BASE_DN}"
log "LDAP_URI=${LDAP_URI}"

OU_SERVICE="OU=ServiceAccounts,${BASE_DN}"
OU_USERS="OU=Users,${BASE_DN}"
OU_GROUPS="OU=Groups,${BASE_DN}"

GROUP_ADMINS="APP_admins"
GROUP_USER_READ="APP_user_read"
GROUP_USER_WRITE="APP_user_write"

SVC_USER="svc_keycloak"
SVC_PASS="${SVC_PASS:-SvcKeycloakPassw0rd!}"

ALICE_USER="alice"
ALICE_PASS="${ALICE_PASS:-AlicePassw0rd!}"

BOB_USER="bob"
BOB_PASS="${BOB_PASS:-BobPassw0rd!}"

# ---- Helpers ----
smb() {
  # Используем samba-tool с явным LDAP URI
  samba-tool "$@" -H "${LDAP_URI}" -U "${ADMIN_USER}%${ADMIN_PASS}"
}

ou_exists() {
  local dn="$1"
  smb ou list 2>/dev/null | grep -Fxq "$dn"
}

ensure_ou() {
  local dn="$1"
  if ou_exists "$dn"; then
    log "OU exists: $dn"
  else
    log "Creating OU: $dn"
    smb ou create "$dn"
  fi
}

group_exists() {
  local name="$1"
  smb group list 2>/dev/null | grep -Fxq "$name"
}

ensure_group() {
  local name="$1"
  if group_exists "$name"; then
    log "Group exists: $name"
  else
    log "Creating group: $name"
    smb group add "$name"
  fi
}

user_exists() {
  local name="$1"
  smb user show "$name" >/dev/null 2>&1
}

ensure_user() {
  local user="$1"
  local pass="$2"
  local ou_short="$3"
  local given="$4"
  local sn="$5"
  local mail="$6"

  if user_exists "$user"; then
    log "User exists: $user"
  else
    log "Creating user: $user (OU=$ou_short)"
    smb user create "$user" "$pass" \
      --userou="$ou_short" \
      --given-name="$given" \
      --surname="$sn" \
      --mail-address="$mail"
  fi
}

add_member_safe() {
  local group="$1"
  local user="$2"
  smb group addmembers "$group" "$user" >/dev/null 2>&1 || true
}

# ---- Main ----
log "Starting bootstrap..."

# Sanity check: LDAP reachable + creds ok
log "Checking admin credentials via group list..."
smb group list >/dev/null

ensure_ou "$OU_SERVICE"
ensure_ou "$OU_USERS"
ensure_ou "$OU_GROUPS"

ensure_group "$GROUP_ADMINS"
ensure_group "$GROUP_USER_READ"
ensure_group "$GROUP_USER_WRITE"

ensure_user "$SVC_USER" "$SVC_PASS" "ServiceAccounts" "Keycloak" "Bind" "svc_keycloak@example.test"
ensure_user "$ALICE_USER" "$ALICE_PASS" "Users" "Alice" "Reader" "alice@example.test"
ensure_user "$BOB_USER" "$BOB_PASS" "Users" "Bob" "Admin" "bob@example.test"

add_member_safe "$GROUP_USER_READ" "$ALICE_USER"
add_member_safe "$GROUP_ADMINS" "$BOB_USER"
add_member_safe "$GROUP_USER_READ" "$BOB_USER"
add_member_safe "$GROUP_USER_WRITE" "$BOB_USER"

log "Done."
