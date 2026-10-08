#!/usr/bin/env bash
set -euo pipefail

invoke_os_updates () {
  echo -e "${CYAN}[OS Updates] Start${NC}"

  osu_update_sources_for_distro
  osu_apt_update
  osu_fix_broken_packages
  osu_unhold_packages
  osu_install_important_updates

  echo -e "${CYAN}[OS Updates] Done${NC}"
}

# ------------------------------------------------------------
# Update APT sources based on distro/codename (Debian family)
# ------------------------------------------------------------
osu_update_sources_for_distro () {
  case "$DISTRO" in
Ubuntu|ubuntu)
if [[ -f /etc/apt/sources.list ]]; then
sudo cp -a /etc/apt/sources.list "/etc/apt/sources.list.$(date +%Y%m%d_%H%M%S).bak"
fi

    if sudo tee /etc/apt/sources.list >/dev/null <<EOF

deb http://archive.ubuntu.com/ubuntu $CODENAME main universe multiverse
deb http://archive.ubuntu.com/ubuntu $CODENAME-updates main universe multiverse
deb http://security.ubuntu.com/ubuntu $CODENAME-security main universe multiverse
deb http://archive.ubuntu.com/ubuntu $CODENAME-backports main universe multiverse
EOF
then
echo "Ubuntu APT sources updated for $CODENAME."
else
echo "Warning: Failed to update Ubuntu APT sources."
fi
;;

LinuxMint|linuxmint|Mint|mint)
    source /etc/os-release
    UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"

    if [[ -z "$UBUNTU_CODENAME" ]]; then
        echo "Warning: UBUNTU_CODENAME not found; Mint sources were not changed."
    else
        file="/etc/apt/sources.list.d/official-package-repositories.list"

        if [[ -f "$file" ]]; then
            sudo cp -a "$file" "$file.$(date +%Y%m%d_%H%M%S).bak"
        fi

        if sudo tee "$file" >/dev/null <<EOF

deb http://packages.linuxmint.com $CODENAME main upstream import backport
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
then
echo "Linux Mint APT sources updated for $CODENAME using Ubuntu $UBUNTU_CODENAME."
else
echo "Warning: Failed to update Linux Mint APT sources."
fi
fi
;;

Debian|debian)
    echo "Debian detected; leaving sources as-is."
    ;;

*)
    echo "Unknown distribution; leaving APT sources as-is."
    ;;

esac
}

# ------------------------------------------------------------
# apt update
# ------------------------------------------------------------
osu_apt_update () {
echo "Updating APT package indexes..."

if sudo apt update -qq; then
echo "APT package indexes updated."
else
echo "Warning: APT package index update failed."
fi
}

# ------------------------------------------------------------
# Install available OS/security updates without overwriting locally
# modified configuration files.
# ------------------------------------------------------------
osu_install_important_updates () {
  echo "Installing available important/security updates..."

  if sudo DEBIAN_FRONTEND=noninteractive \
    apt-get \
    -o Dpkg::Options::="--force-confold" \
    --with-new-pkgs \
    upgrade -y; then
    echo "Important/security updates installed."
  else
    echo "Warning: Important/security update installation failed."
  fi
}

# ------------------------------------------------------------
# apt --fix-broken install
# ------------------------------------------------------------
osu_fix_broken_packages () {
 echo "Attempting to fix broken package dependencies..."

if sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -qq; then
echo "Broken package dependencies fixed."
else
echo "Warning: Failed to fix broken package dependencies."
fi
}

# ------------------------------------------------------------
# apt-mark: unhold all currently held packages
# ------------------------------------------------------------
osu_unhold_packages () {
held_packages=$(apt-mark showhold)

if [[ -z "$held_packages" ]]; then
echo "No held packages found."
return
fi

while IFS= read -r package; do
[[ -z "$package" ]] && continue

if sudo apt-mark unhold "$package" >/dev/null 2>&1; then
    echo "Unheld: $package"
else
    echo "Warning: Failed to unhold $package; continuing."
fi

done <<< "$held_packages"
}

