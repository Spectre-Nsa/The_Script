#!/usr/bin/env bash
set -euo pipefail

invoke_service_auditing () {
  echo -e "${CYAN}[Service Auditing] Start${NC}"

  sa_purge_unwanted_services

  echo -e "${CYAN}[Service Auditing] Done${NC}"
}

# -------------------------------------------------------------------
# Interactively purge unwanted packages listed in $UNWANTED
# -------------------------------------------------------------------
sa_purge_unwanted_services () {
  if [[ -z "${UNWANTED+x}" || -z "${UNWANTED}" ]]; then
echo "No unwanted services configured."
return
fi

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

        if sudo DEBIAN_FRONTEND=noninteractive apt purge -y -qq "${pkg}*" >/dev/null 2>&1; then
            echo "${pkg} purged."
        else
            echo "Error: Purge failed for ${pkg}; repairing dpkg state..."

            sudo dpkg --configure -a >/dev/null 2>&1 || true

            if sudo DEBIAN_FRONTEND=noninteractive apt purge -y -qq "${pkg}*" >/dev/null 2>&1; then
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
