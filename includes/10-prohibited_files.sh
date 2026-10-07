#!/usr/bin/env bash
set -euo pipefail

invoke_prohibited_files () {
  echo -e "${CYAN}[Prohibited Files] Start${NC}"

  pf_remove_prohibited_files

  echo -e "${CYAN}[Prohibited Files] Done${NC}"
}

# -------------------------------------------------------------------
# Remove files matching extensions from $FILE_EXTENSIONS
# -------------------------------------------------------------------
pf_remove_prohibited_files () {
  
if [[ -z "${FILE_EXTENSIONS+x}" || ${#FILE_EXTENSIONS[@]} -eq 0 ]]; then
echo "No file extensions configured."
return
fi

for ext in "${FILE_EXTENSIONS[@]}"; do
echo "Searching and removing files with .${ext} extension..."

find / -type f -name "*.${ext}" -exec rm -f -- {} + 2>/dev/null || true

done

echo "File extension cleanup complete."
}
