#!/usr/bin/env bash
set -euo pipefail

invoke_unwanted_software () {
  echo -e "${CYAN}[Unwanted Software] Start${NC}"

  us_purge_unwanted_software

  echo -e "${CYAN}[Unwanted Software] Done${NC}"
}

# -------------------------------------------------------------------
# Purge unwanted software listed in $UNWANTED_SOFTWARE, then autoremove
# -------------------------------------------------------------------
us_purge_unwanted_software () {
 if [[ -z "${UNWANTED_SOFTWARE+x}" ]]; then
echo "No unwanted software configured."
return
fi

if declare -p UNWANTED_SOFTWARE 2>/dev/null | grep -q 'declare -a'; then
packages=("${UNWANTED_SOFTWARE[@]}")
else
read -r -a packages <<< "$UNWANTED_SOFTWARE"
fi

if [[ ${#packages[@]} -eq 0 ]]; then
echo "No unwanted software configured."
return
fi

for name in "${packages[@]}"; do
[[ -z "$name" ]] && continue

echo "Purging unwanted package: ${name}..."

if sudo DEBIAN_FRONTEND=noninteractive apt purge -y -qq "${name}*" >/dev/null 2>&1; then
    echo "Purged ${name}."
else
    echo "Warning: Initial purge failed for ${name}; repairing dpkg state..."

    sudo dpkg --configure -a >/dev/null 2>&1 || true

    if sudo DEBIAN_FRONTEND=noninteractive apt purge -y -qq "${name}*" >/dev/null 2>&1; then
        echo "Purged ${name} after retry."
    else
        echo "Warning: Final purge failed for ${name}."
    fi
fi

done

sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y -qq >/dev/null 2>&1 ||
echo "Warning: APT autoremove encountered an error."

echo "Autoremove complete."
}
