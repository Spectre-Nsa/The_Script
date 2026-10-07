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
  : <<'AI_BLOCK'
EXPLANATION
Delete files across the filesystem whose extensions are listed in the Bash array $FILE_EXTENSIONS
(defined in config.sh). For each extension, print a status line before deleting matching files.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Read the Bash array $FILE_EXTENSIONS. If unset or empty, print "No file extensions configured." and return.
- For each extension value (e.g., mp3), print: "Searching and removing files with .<ext> extension..."
- Recursively search from / for regular files matching "*.<ext>" and delete them.
- Suppress noisy errors (e.g., permission denied) so the loop continues.
- Continue on errors for individual deletions; do not abort the script.
- Print minimal confirmations or a final summary when done.
AI_BLOCK
}
