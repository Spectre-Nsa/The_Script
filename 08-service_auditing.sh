#!/usr/bin/env bash

# Enable strict mode only when this file is executed directly.
# harden.sh sources includes/*.sh, so strict mode must not leak into the parent shell.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

invoke_service_auditing () {
  echo -e "${CYAN}[Service Auditing] Start${NC}"

  # SSH is a critical service for this competition round.
  # A failure here is reported but must not terminate the entire hardening script.
  if ! sa_secure_critical_ssh; then
    echo "Warning: Critical SSH remediation encountered an error."
  fi

  if ! sa_purge_unwanted_services; then
    echo "Warning: Unwanted service cleanup encountered an error."
  fi

  echo -e "${CYAN}[Service Auditing] Done${NC}"
}

# -------------------------------------------------------------------
# Critical SSH service: install, enable, start, and harden OpenSSH
# -------------------------------------------------------------------
sa_secure_critical_ssh () {
  echo
  echo "============================================================"
  echo "CRITICAL SERVICE: SSH / OPENSSH"
  echo "============================================================"

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Warning: SSH hardening requires root."
    return 1
  fi

  local package="openssh-server"
  local config="/etc/ssh/sshd_config"
  local timestamp
  local backup=""
  local tmp=""
  local service=""
  local effective=""
  local value=""
  local port="22"

  timestamp="$(date +%Y%m%d_%H%M%S)"

  # ---------------------------------------------------------------
  # 1. Make sure OpenSSH server is installed
  # ---------------------------------------------------------------
  if ! command -v sshd >/dev/null 2>&1; then
    echo "OpenSSH server is not installed."
    echo "Installing $package..."

    if ! DEBIAN_FRONTEND=noninteractive \
      apt-get \
      -o Dpkg::Options::="--force-confold" \
      install -y "$package"; then

      echo "Initial OpenSSH installation failed."
      echo "Refreshing APT package indexes and retrying..."

      if ! apt-get update; then
        echo "Warning: APT index refresh failed."
        return 1
      fi

      if ! DEBIAN_FRONTEND=noninteractive \
        apt-get \
        -o Dpkg::Options::="--force-confold" \
        install -y "$package"; then

        echo "Error: Could not install OpenSSH server."
        return 1
      fi
    fi
  else
    echo "OpenSSH server is already installed."
  fi

  # ---------------------------------------------------------------
  # 2. Locate the SSH systemd service
  # ---------------------------------------------------------------
  if systemctl cat ssh.service >/dev/null 2>&1; then
    service="ssh"
  elif systemctl cat sshd.service >/dev/null 2>&1; then
    service="sshd"
  else
    echo "Error: Could not locate an SSH systemd service."
    return 1
  fi

  echo "SSH service detected: $service"

  # ---------------------------------------------------------------
  # 3. Make sure required configuration directories exist
  # ---------------------------------------------------------------
  if [[ ! -d /etc/ssh ]]; then
    echo "Error: /etc/ssh does not exist."
    return 1
  fi

  if [[ ! -f "$config" ]]; then
    echo "Error: $config does not exist."
    return 1
  fi

  mkdir -p /etc/ssh/sshd_config.d
  install -d -m 0755 /run/sshd

  # ---------------------------------------------------------------
  # 4. Generate any missing host keys
  # ---------------------------------------------------------------
  echo "Checking SSH host keys..."

  if ! compgen -G "/etc/ssh/ssh_host_*_key" >/dev/null 2>&1; then
    echo "No SSH host private keys found. Generating missing keys..."
    if ! ssh-keygen -A; then
      echo "Error: SSH host key generation failed."
      return 1
    fi
  else
    echo "SSH host keys already exist."
    ssh-keygen -A >/dev/null 2>&1 || true
  fi

  # ---------------------------------------------------------------
  # 5. Fix host-key and main-config permissions
  # ---------------------------------------------------------------
  for value in /etc/ssh/ssh_host_*_key; do
    [[ -f "$value" ]] || continue
    chown root:root "$value"
    chmod 0600 "$value"
  done

  for value in /etc/ssh/ssh_host_*_key.pub; do
    [[ -f "$value" ]] || continue
    chown root:root "$value"
    chmod 0644 "$value"
  done

  chmod 0644 "$config"
  chown root:root "$config"

  # ---------------------------------------------------------------
  # 6. Back up sshd_config before modifying it
  # ---------------------------------------------------------------
  backup="${config}.${timestamp}.bak"

  if ! cp -a "$config" "$backup"; then
    echo "Error: Could not back up $config."
    return 1
  fi

  echo "Backup created: $backup"

  # ---------------------------------------------------------------
  # 7. Place a hardened baseline at the top of sshd_config.
  #    Existing copies of the same global directives before the first
  #    Match block are removed so the effective configuration is clear.
  # ---------------------------------------------------------------
  tmp="$(mktemp /etc/ssh/.sshd_config.XXXXXX)" || {
    echo "Error: Could not create temporary SSH configuration."
    return 1
  }

  if ! awk '
  BEGIN {
      print "# NOJE Critical SSH Hardening"
      print "PermitRootLogin no"
      print "PermitEmptyPasswords no"
      print "PasswordAuthentication yes"
      print "PubkeyAuthentication yes"
      print "UsePAM yes"
      print "MaxAuthTries 4"
      print "LoginGraceTime 60"
      print "X11Forwarding no"
      print "PermitUserEnvironment no"
      print "ClientAliveInterval 300"
      print "ClientAliveCountMax 2"
      print ""
      match_seen = 0
  }

  /^[[:space:]]*[Mm][Aa][Tt][Cc][Hh][[:space:]]+/ {
      match_seen = 1
  }

  {
      if (!match_seen && $0 ~ /^[[:space:]]*[Pp][Ee][Rr][Mm][Ii][Tt][Rr][Oo][Oo][Tt][Ll][Oo][Gg][Ii][Nn][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Pp][Ee][Rr][Mm][Ii][Tt][Ee][Mm][Pp][Tt][Yy][Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][Ss][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][Aa][Uu][Tt][Hh][Ee][Nn][Tt][Ii][Cc][Aa][Tt][Ii][Oo][Nn][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Pp][Uu][Bb][Kk][Ee][Yy][Aa][Uu][Tt][Hh][Ee][Nn][Tt][Ii][Cc][Aa][Tt][Ii][Oo][Nn][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Uu][Ss][Ee][Pp][Aa][Mm][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Mm][Aa][Xx][Aa][Uu][Tt][Hh][Tt][Rr][Ii][Ee][Ss][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Ll][Oo][Gg][Ii][Nn][Gg][Rr][Aa][Cc][Ee][Tt][Ii][Mm][Ee][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Xx][11][Ff][Oo][Rr][Ww][Aa][Rr][Dd][Ii][Nn][Gg][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Pp][Ee][Rr][Mm][Ii][Tt][Uu][Ss][Ee][Rr][Ee][Nn][Vv][Ii][Rr][Oo][Nn][Mm][Ee][Nn][Tt][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Cc][Ll][Ii][Ee][Nn][Tt][Aa][Ll][Ii][Vv][Ee][Ii][Nn][Tt][Ee][Rr][Vv][Aa][Ll][[:space:]]+/) next
      if (!match_seen && $0 ~ /^[[:space:]]*[Cc][Ll][Ii][Ee][Nn][Tt][Aa][Ll][Ii][Vv][Ee][Cc][Oo][Uu][Nn][Tt][Mm][Aa][Xx][[:space:]]+/) next

      print
  }
  ' "$config" > "$tmp"; then
    rm -f "$tmp"
    echo "Error: Could not construct hardened SSH configuration."
    return 1
  fi

  chown root:root "$tmp"
  chmod 0644 "$tmp"

  if ! install -m 0644 -o root -g root "$tmp" "$config"; then
    rm -f "$tmp"
    echo "Error: Could not install hardened SSH configuration."
    return 1
  fi

  rm -f "$tmp"
  tmp=""

  # ---------------------------------------------------------------
  # 8. Validate configuration BEFORE touching the running service
  # ---------------------------------------------------------------
  echo "Validating SSH configuration..."

  if ! sshd -t; then
    echo "ERROR: sshd configuration validation failed."
    echo "Rolling back $config..."

    if cp -a "$backup" "$config"; then
      echo "SSH configuration rolled back successfully."
    else
      echo "CRITICAL ERROR: SSH configuration rollback failed."
    fi

    return 1
  fi

  echo "SSH configuration syntax is valid."

  # ---------------------------------------------------------------
  # 9. Read the effective configuration
  # ---------------------------------------------------------------
  effective="$(sshd -T 2>/dev/null)" || {
    echo "Error: Could not read effective SSH configuration."
    cp -a "$backup" "$config"
    return 1
  }

  value="$(awk '$1=="permitrootlogin"{print $2; exit}' <<< "$effective")"
  if [[ "$value" != "no" ]]; then
    echo "Error: PermitRootLogin is not effectively set to no."
    echo "Effective value: ${value:-unknown}"
    cp -a "$backup" "$config"
    return 1
  fi

  value="$(awk '$1=="permitemptypasswords"{print $2; exit}' <<< "$effective")"
  if [[ "$value" != "no" ]]; then
    echo "Error: PermitEmptyPasswords is not effectively set to no."
    echo "Effective value: ${value:-unknown}"
    cp -a "$backup" "$config"
    return 1
  fi

  value="$(awk '$1=="passwordauthentication"{print $2; exit}' <<< "$effective")"
  if [[ "$value" != "yes" ]]; then
    echo "Error: PasswordAuthentication is not enabled."
    echo "This could prevent competition password authentication."
    echo "Effective value: ${value:-unknown}"
    cp -a "$backup" "$config"
    return 1
  fi

  value="$(awk '$1=="maxauthtries"{print $2; exit}' <<< "$effective")"
  if [[ "$value" != "4" ]]; then
    echo "Warning: MaxAuthTries effective value is ${value:-unknown}."
  fi

  port="$(awk '$1=="port"{print $2; exit}' <<< "$effective")"
  [[ -n "$port" ]] || port="22"

  echo "Effective SSH port: $port"

  # ---------------------------------------------------------------
  # 10. Unmask, enable, and start SSH
  # ---------------------------------------------------------------
  echo "Ensuring SSH service is enabled and running..."

  systemctl unmask "$service" >/dev/null 2>&1 || true

  if ! systemctl enable "$service"; then
    echo "Error: Could not enable $service."
    cp -a "$backup" "$config"
    return 1
  fi

  if systemctl is-active --quiet "$service"; then
    echo "SSH is already running."

    if ! systemctl reload "$service"; then
      echo "Warning: SSH reload failed."
      echo "Rolling back configuration..."

      cp -a "$backup" "$config"
      systemctl reload "$service" >/dev/null 2>&1 || true

      return 1
    fi
  else
    echo "SSH is not running. Starting it..."

    if ! systemctl start "$service"; then
      echo "Error: SSH failed to start."
      echo "Rolling back configuration..."

      cp -a "$backup" "$config"
      systemctl start "$service" >/dev/null 2>&1 || true

      return 1
    fi
  fi

  # ---------------------------------------------------------------
  # 11. Final service verification
  # ---------------------------------------------------------------
  if ! systemctl is-active --quiet "$service"; then
    echo "ERROR: SSH service is not active after remediation."
    return 1
  fi

  if ! systemctl is-enabled --quiet "$service"; then
    echo "ERROR: SSH service is not enabled."
    return 1
  fi

  echo
  echo "SSH HARDENING COMPLETE"
  echo "-----------------------"
  echo "Service:                $service"
  echo "Status:                 ACTIVE"
  echo "Enabled:                YES"
  echo "PermitRootLogin:        no"
  echo "PermitEmptyPasswords:   no"
  echo "PasswordAuthentication: yes"
  echo "MaxAuthTries:           4"
  echo "X11Forwarding:          no"
  echo "SSH Port:               $port"
  echo "Backup:                 $backup"
  echo
  echo "Critical SSH service is enabled, running, and hardened."

  return 0
}

# -------------------------------------------------------------------
# Interactively purge unwanted packages listed in $UNWANTED
# -------------------------------------------------------------------
sa_purge_unwanted_services () {
  if [[ -z "${UNWANTED+x}" || -z "${UNWANTED}" ]]; then
    echo "No unwanted services configured."
    return 0
  fi

  local -a packages=()
  local pkg answer

  if declare -p UNWANTED 2>/dev/null | grep -q 'declare -a'; then
    packages=("${UNWANTED[@]}")
  else
    read -r -a packages <<< "$UNWANTED"
  fi

  for pkg in "${packages[@]}"; do
    [[ -z "$pkg" ]] && continue

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
      read -r -p "Is the service ${pkg} a critical service? (Y/n) " answer
      answer="${answer:-Y}"

      if [[ "$answer" == "n" || "$answer" == "N" ]]; then
        echo "Purging ${pkg}..."

        if DEBIAN_FRONTEND=noninteractive apt purge -y -qq "${pkg}*" >/dev/null 2>&1; then
          echo "${pkg} purged."
        else
          echo "Error: Purge failed for ${pkg}; repairing dpkg state..."

          dpkg --configure -a >/dev/null 2>&1 || true

          if DEBIAN_FRONTEND=noninteractive apt purge -y -qq "${pkg}*" >/dev/null 2>&1; then
            echo "${pkg} purged after retry."
          else
            echo "Final failure: Could not purge ${pkg}."
          fi
        fi
      else
        echo "${pkg} kept."
      fi
    else
      echo "${pkg} not installed. Skipping..."
    fi
  done
}
