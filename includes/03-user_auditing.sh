#!/usr/bin/env bash
# Enable strict mode only when executed directly. When sourced by harden.sh,
# do not leak errexit into the parent interactive shell.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

invoke_user_auditing () {
  echo -e "${CYAN}[User Auditing] Start${NC}"

  if ! ua_overview_real_users; then
    echo "Warning: Real-user overview encountered an error; continuing."
  fi

  if ! ua_audit_interactive_remove_unauthorized_users; then
    echo "Warning: User authorization audit encountered an error; continuing."
  fi

  if ! ua_overview_administrators; then
    echo "Warning: Administrator overview encountered an error; continuing."
  fi

  if ! ua_force_temp_passwords; then
    echo "Warning: Temporary password assignment encountered an error; continuing."
  fi

  if ! ua_remove_non_root_uid0; then
    echo "Warning: UID 0 cleanup encountered an error; continuing."
  fi

  if ! ua_set_password_aging_policy; then
    echo "Warning: Password aging policy encountered an error; continuing."
  fi

  if ! ua_set_shells_standard_and_root_bash; then
    echo "Warning: Standard/root shell normalization encountered an error; continuing."
  fi

  if ! ua_set_shells_system_accounts_nologin; then
    echo "Warning: System-account shell normalization encountered an error; continuing."
  fi

  echo -e "${CYAN}[User Auditing] Done${NC}"
  return 0
}

# -------------------------------------------------------------------
# Read-only overview of likely human/real users, including persistent
# detection of lower-UID human-like accounts. A lower-UID account with
# a /home path remains visible even after its shell is changed to
# /usr/sbin/nologin, so a second audit still catches it.
# -------------------------------------------------------------------
ua_overview_real_users () {
  local uid_min valid_shells
  uid_min=$(awk '$1 == "UID_MIN" {print $2; exit}' /etc/login.defs 2>/dev/null || true)
  [[ "$uid_min" =~ ^[0-9]+$ ]] || uid_min=1000
  valid_shells=$(grep -vE '^[[:space:]]*(#|$)' /etc/shells 2>/dev/null || true)

  declare -A admin_source=()
  declare -A records=()
  local members user

  while IFS= read -r members; do
    [[ -z "$members" ]] && continue
    IFS=',' read -ra users_in_group <<< "$members"
    for user in "${users_in_group[@]}"; do
      [[ -n "$user" ]] && admin_source["$user"]+="${admin_source[$user]:+,}sudo"
    done
  done < <(getent group sudo | awk -F: '{print $4}')

  while IFS= read -r members; do
    [[ -z "$members" ]] && continue
    IFS=',' read -ra users_in_group <<< "$members"
    for user in "${users_in_group[@]}"; do
      [[ -n "$user" ]] && admin_source["$user"]+="${admin_source[$user]:+,}wheel"
    done
  done < <(getent group wheel | awk -F: '{print $4}')

  while IFS=: read -r user _ uid _ _ home shell; do
    local is_real=0 hidden=0 source="UID"
    local home_real=0 shell_real=0

    if [[ "$uid" =~ ^[0-9]+$ && "$uid" -ge "$uid_min" ]]; then
      is_real=1
    fi

    if [[ "$home" == /home/* || "$home" == /root ]]; then
      home_real=1
    fi

    if [[ -n "$valid_shells" ]] && printf '%s\n' "$valid_shells" | grep -Fxq "$shell"; then
      shell_real=1
    fi

    # Do not rely on the shell alone for low-UID human-like accounts.
    # Once the account is hardened to nologin, its /home path still
    # identifies it as a candidate on later audit passes.
    if [[ "$uid" =~ ^[0-9]+$ && "$uid" -gt 0 && "$uid" -lt "$uid_min" && ( "$home_real" -eq 1 || "$shell_real" -eq 1 ) ]]; then
      is_real=1
      hidden=1
      source="LOW-UID-HUMAN-LIKE"
    fi

    [[ "$is_real" -eq 1 ]] || continue

    if [[ "$hidden" -eq 1 ]]; then
      source="LOW-UID-HUMAN-LIKE"
    elif [[ "$home_real" -eq 1 && "$shell_real" -eq 1 ]]; then
      source="UID/HOME/SHELL"
    fi

    if [[ "$uid" == "0" ]]; then
      admin_source["$user"]="root"
    fi

    records["$user"]=$'\t'"$uid"$'\t'"$home"$'\t'"$shell"$'\t'"$source"
  done < <(getent passwd)

  echo
  echo "================ REAL USER OVERVIEW ================"
  echo "Administrators first; lower-UID human-like accounts are marked as hidden candidates."
  echo

  local printed=0 key record uid home shell source admin

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    [[ -n "${admin_source[$key]:-}" ]] || continue
    record="${records[$key]}"
    IFS=$'\t' read -r uid home shell source <<< "$record"
    printf 'ADMIN  %-24s UID=%-5s SOURCE=%-22s HOME=%s SHELL=%s\n' "$key" "$uid" "${admin_source[$key]}" "$home" "$shell"
    printed=1
  done < <(printf '%s\n' "${!records[@]}" | sort)

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    [[ -n "${admin_source[$key]:-}" ]] && continue
    record="${records[$key]}"
    IFS=$'\t' read -r uid home shell source <<< "$record"
    if [[ "$source" == "LOW-UID-HUMAN-LIKE" ]]; then
      printf 'HIDDEN %-24s UID=%-5s SOURCE=%-22s HOME=%s SHELL=%s\n' "$key" "$uid" "$source" "$home" "$shell"
    else
      printf 'USER   %-24s UID=%-5s SOURCE=%-22s HOME=%s SHELL=%s\n' "$key" "$uid" "$source" "$home" "$shell"
    fi
    printed=1
  done < <(printf '%s\n' "${!records[@]}" | sort)

  [[ "$printed" -eq 1 ]] || echo "No likely human users were found."
  echo "====================================================="
  echo
}

# -------------------------------------------------------------------
# Read-only administrator overview. No users are removed here.
# -------------------------------------------------------------------
ua_overview_administrators () {
  local found=0 user uid groups
  echo "================ ADMINISTRATOR OVERVIEW ============="

  if getent passwd root >/dev/null 2>&1; then
    printf 'ADMIN  %-24s UID=%-5s SOURCE=root\n' "root" "$(getent passwd root | awk -F: '{print $3}')"
    found=1
  fi

  while IFS= read -r user; do
    [[ -n "$user" ]] || continue
    uid=$(getent passwd "$user" | awk -F: 'NR == 1 {print $3}')
    groups=$(id -nG "$user" 2>/dev/null || true)
    if [[ "$groups" == *"sudo"* || "$groups" == *"wheel"* ]]; then
      printf 'ADMIN  %-24s UID=%-5s GROUPS=%s\n' "$user" "$uid" "$groups"
      found=1
    fi
  done < <(getent group sudo | awk -F: '{gsub(/,/,"\n",$4); print $4}')

  while IFS= read -r user; do
    [[ -n "$user" ]] || continue
    uid=$(getent passwd "$user" | awk -F: 'NR == 1 {print $3}')
    groups=$(id -nG "$user" 2>/dev/null || true)
    if [[ "$groups" == *"sudo"* || "$groups" == *"wheel"* ]]; then
      printf 'ADMIN  %-24s UID=%-5s GROUPS=%s\n' "$user" "$uid" "$groups"
      found=1
    fi
  done < <(getent group wheel | awk -F: '{gsub(/,/,"\n",$4); print $4}')

  [[ "$found" -eq 1 ]] || echo "No administrators found."
  echo "====================================================="
  echo
  echo "No users were removed; this is an overview only."
}

# -------------------------------------------------------------------
# Interactive audit of likely human users. This deliberately keeps
# low-UID accounts with /home paths visible even after their shell has
# been changed to /usr/sbin/nologin by the hardening pass.
# -------------------------------------------------------------------
ua_audit_interactive_remove_unauthorized_users () {
  local valid_shells uid_min
  valid_shells=$(grep -vE '^[[:space:]]*(#|$)' /etc/shells 2>/dev/null || true)
  uid_min=$(awk '$1 == "UID_MIN" {print $2; exit}' /etc/login.defs 2>/dev/null || true)
  [[ "$uid_min" =~ ^[0-9]+$ ]] || uid_min=1000

  getent passwd |
  while IFS=: read -r user _ uid _ _ home shell; do
    [[ "$user" == "root" || "$uid" == "0" ]] && continue

    local candidate=0

    # Normal human accounts remain candidates even when their shell is
    # nologin, because UID >= UID_MIN is the primary classification.
    if [[ "$uid" =~ ^[0-9]+$ && "$uid" -ge "$uid_min" ]]; then
      candidate=1
    fi

    # Persistent hidden-account heuristic: a lower-UID account with a
    # /home path is still a likely human account after shell hardening.
    if [[ "$uid" =~ ^[0-9]+$ && "$uid" -gt 0 && "$uid" -lt "$uid_min" && "$home" == /home/* ]]; then
      candidate=1
    fi

    # Preserve the previous valid-login-shell heuristic for unusual
    # accounts whose home path does not look like /home/...
    if [[ -n "$valid_shells" ]] && printf '%s\n' "$valid_shells" | grep -Fxq "$shell"; then
      candidate=1
    fi

    [[ "$candidate" -eq 1 ]] || continue

    read -r -p "Is $user an Authorized User? [Y/n] " answer
    answer="${answer:-Y}"

    if [[ "$answer" == "n" || "$answer" == "N" ]]; then
      if sudo userdel -r "$user" >/dev/null 2>&1; then
        echo "Removed unauthorized user: $user"
      else
        echo "Warning: Could not remove user: $user"
      fi
    else
      echo "$user is authorized."
    fi
  done
}

# -------------------------------------------------------------------
# Force temporary passwords for all users
# -------------------------------------------------------------------
ua_force_temp_passwords () {
  local password
  password="${TEMP_PASSWORD:-1CyberPatriot!}"

  getent passwd | cut -d: -f1 | while IFS= read -r user; do
    if printf '%s:%s\n' "$user" "$password" | sudo chpasswd -c SHA512 2>/dev/null; then
      echo "Set temporary password for $user."
    else
      echo "Warning: Could not set password for $user."
    fi
  done
}

# -------------------------------------------------------------------
# Remove any UID 0 accounts that are not 'root'
# -------------------------------------------------------------------
ua_remove_non_root_uid0 () {
  getent passwd | while IFS=: read -r user _ uid _ _ _ _; do
    if [[ "$uid" == "0" && "$user" != "root" ]]; then
      if sudo userdel -r -f "$user" >/dev/null 2>&1; then
        echo "Removed UID 0 account: $user"
      else
        echo "Warning: Could not remove UID 0 account: $user"
      fi
    fi
  done
}

# -------------------------------------------------------------------
# Set password aging policy for all users (Debian family)
# -------------------------------------------------------------------
ua_set_password_aging_policy () {
  getent passwd | cut -d: -f1 | while IFS= read -r user; do
    if sudo chage -M 60 -m 10 -W 7 "$user" >/dev/null 2>&1; then
      echo "Applied password aging policy to $user."
    else
      echo "Warning: Could not apply password aging policy to $user."
    fi
  done
}

# -------------------------------------------------------------------
# Set shells for standard users and root to /bin/bash
# -------------------------------------------------------------------
ua_set_shells_standard_and_root_bash () {
  while IFS=: read -r user _ uid _ _ _ _; do
    if [[ "$uid" -eq 0 || "$uid" -ge 1000 ]]; then
      if sudo usermod -s /bin/bash "$user" >/dev/null 2>&1; then
        echo "Changed shell for $user to /bin/bash."
      else
        echo "Warning: Could not change shell for $user."
      fi
    fi
  done < /etc/passwd
}

# -------------------------------------------------------------------
# Set shells for system accounts to /usr/sbin/nologin
# -------------------------------------------------------------------
ua_set_shells_system_accounts_nologin () {
  while IFS=: read -r user _ uid _ _ _ _; do
    if [[ "$uid" -ge 1 && "$uid" -le 999 ]]; then
      if sudo usermod -s /usr/sbin/nologin "$user" >/dev/null 2>&1; then
        echo "Changed shell for $user to /usr/sbin/nologin."
      else
        echo "Warning: Could not change shell for $user."
      fi
    fi
  done < /etc/passwd
}
