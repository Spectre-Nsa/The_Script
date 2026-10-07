#!/usr/bin/env bash
set -euo pipefail

invoke_user_auditing () {
  echo -e "${CYAN}[User Auditing] Start${NC}"

  ua_audit_interactive_remove_unauthorized_users
  ua_audit_interactive_remove_unauthorized_sudoers
  ua_force_temp_passwords
  ua_remove_non_root_uid0
  ua_set_password_aging_policy
  ua_set_shells_standard_and_root_bash
  ua_set_shells_system_accounts_nologin

  echo -e "${CYAN}[User Auditing] Done${NC}"
}

# -------------------------------------------------------------------
# 1) Interactive audit of local users with valid login shells
# -------------------------------------------------------------------
ua_audit_interactive_remove_unauthorized_users () {
valid_shells=$(grep -vE '^[[:space:]]*(#|$)' /etc/shells 2>/dev/null)

if [[ -z "$valid_shells" ]]; then
echo "Warning: No valid login shells found in /etc/shells."
else
getent passwd |
while IFS=: read -r user _ uid _ _ home shell; do
if printf '%s\n' "$valid_shells" | grep -Fxq "$shell"; then
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
    fi
done

fi
}

# -------------------------------------------------------------------
# 2) Interactive audit of sudoers; remove unauthorized admins
# -------------------------------------------------------------------
ua_audit_interactive_remove_unauthorized_sudoers () {
for user in "${users[@]}"; do
    [[ -z "$user" ]] && continue

    read -r -p "Is $user an Authorized Administrator? [Y/n] " answer
    answer="${answer:-Y}"

    if [[ "$answer" == "n" || "$answer" == "N" ]]; then
        if sudo deluser "$user" sudo >/dev/null 2>&1; then
            echo "Removed $user from sudo group."
        else
            echo "Warning: Could not remove $user from sudo group."
        fi
    else
        echo "$user is authorized."
    fi
done
}

# -------------------------------------------------------------------
# 3) Force temporary passwords for all users
# -------------------------------------------------------------------
ua_force_temp_passwords () {
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
# 4) Remove any UID 0 accounts that are not 'root'
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
# 5) Set password aging policy for all users (Debian family)
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
# 6) Set shells for standard users and root to /bin/bash
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
# 7) Set shells for system accounts to /usr/sbin/nologin
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
