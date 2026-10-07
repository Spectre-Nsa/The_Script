#!/usr/bin/env bash
set -euo pipefail

invoke_account_policy () {
  echo -e "${CYAN}[Account Policy] Start${NC}"

  ap_secure_login_defs
  ap_pam_pwquality_inline
  ap_pwquality_conf_file
  ap_lockout_faillock

  echo -e "${CYAN}[Account Policy] Done${NC}"
}

# -------------------------------------------------------------------
# /etc/login.defs hardening
# -------------------------------------------------------------------
ap_secure_login_defs () {
file="/etc/login.defs"
timestamp=$(date +%Y%m%d_%H%M%S)

if [[ -f "$file" ]]; then
sudo cp -a "$file" "${file}.${timestamp}.bak"
fi

for setting in
"PASS_MAX_DAYS 60"
"PASS_MIN_DAYS 10"
"PASS_WARN_AGE 14"
"UMASK 077"; do

key="${setting%% *}"
value="${setting#* }"

if sudo grep -Eq "^[[:space:]]*#?[[:space:]]*${key}([[:space:]]+.*)?$" "$file" 2>/dev/null; then
    sudo sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}([[:space:]]+.*)?$|${key} ${value}|" "$file"
else
    echo "${key} ${value}" | sudo tee -a "$file" >/dev/null
fi

echo "Set ${key} ${value}."

done
}

# -------------------------------------------------------------------
# Insert pam_pwquality inline in common-password
# -------------------------------------------------------------------
ap_pam_pwquality_inline () {
file="/etc/pam.d/common-password"
timestamp=$(date +%Y%m%d_%H%M%S)
pwquality_line="password requisite pam_pwquality.so retry=3 minlen=10 difok=5 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1"

if [[ -f "$file" ]]; then
sudo cp -a "$file" "${file}.${timestamp}.bak"
fi

if sudo grep -Fqx "$pwquality_line" "$file" 2>/dev/null; then
echo "pwquality rule already in place."
elif sudo grep -q 'pam_unix.so' "$file" 2>/dev/null; then
sudo sed -i "/pam_unix.so/i\${pwquality_line}" "$file"
echo "pwquality rule inserted."
else
echo "Warning: pam_unix.so not found; pwquality rule was not inserted."
fi
}

# -------------------------------------------------------------------
# Configure /etc/security/pwquality.conf
# -------------------------------------------------------------------
ap_pwquality_conf_file () {
  file="/etc/security/pwquality.conf"
timestamp=$(date +%Y%m%d_%H%M%S)

if [[ -f "$file" ]]; then
sudo cp -a "$file" "${file}.${timestamp}.bak"
else
sudo touch "$file"
fi

while read -r key value; do
if sudo grep -Eq "^[[:space:]]#?[[:space:]]${key}[[:space:]]=" "$file"; then
sudo sed -i -E "s|^[[:space:]]#?[[:space:]]${key}[[:space:]]=.*$|${key} = ${value}|" "$file"
else
echo "${key} = ${value}" | sudo tee -a "$file" >/dev/null
fi
echo "Set ${key} = ${value}"
done <<'EOF'
minlen 10
minclass 2
maxrepeat 2
maxclassrepeat 6
lcredit -1
ucredit -1
dcredit -1
ocredit -1
maxsequence 2
difok 5
gecoscheck 1
EOF
}

# -------------------------------------------------------------------
# Configure pam_faillock in common-auth/common-account
# -------------------------------------------------------------------
ap_lockout_faillock () {
auth_file="/etc/pam.d/common-auth"
account_file="/etc/pam.d/common-account"
timestamp=$(date +%Y%m%d_%H%M%S)

sudo cp -a "$auth_file" "${auth_file}.${timestamp}.bak"
sudo cp -a "$account_file" "${account_file}.${timestamp}.bak"

preauth_line="auth required pam_faillock.so preauth"
authfail_line="auth [default=die] pam_faillock.so authfail"
authsucc_line="auth sufficient pam_faillock.so authsucc"
account_line="account required pam_faillock.so"

if ! sudo grep -Eq '^[[:space:]]auth[[:space:]]+required[[:space:]]+pam_faillock.so[[:space:]]+preauth[[:space:]]$' "$auth_file"; then
sudo sed -i "/pam_unix.so/i\$preauth_line" "$auth_file"
echo "Added pam_faillock preauth line."
else
echo "pam_faillock preauth line already present."
fi

if ! sudo grep -Eq '^[[:space:]]auth[[:space:]]+\(default=die\)[[:space:]]+pam_faillock.so[[:space:]]+authfail[[:space:]]$' "$auth_file"; then
sudo sed -i "/pam_unix.so/i\$authfail_line" "$auth_file"
echo "Added pam_faillock authfail line."
else
echo "pam_faillock authfail line already present."
fi

if ! sudo grep -Eq '^[[:space:]]auth[[:space:]]+sufficient[[:space:]]+pam_faillock.so[[:space:]]+authsucc[[:space:]]$' "$auth_file"; then
sudo sed -i "/pam_unix.so/a\$authsucc_line" "$auth_file"
echo "Added pam_faillock authsucc line."
else
echo "pam_faillock authsucc line already present."
fi

if ! sudo grep -Eq '^[[:space:]]account[[:space:]]+required[[:space:]]+pam_faillock.so[[:space:]]$' "$account_file"; then
echo "$account_line" | sudo tee -a "$account_file" >/dev/null
echo "Added pam_faillock account line."
else
echo "pam_faillock account line already present."
fi
}
