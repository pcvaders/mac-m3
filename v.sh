#!/bin/bash
# Verify the backup made by b.sh, using only awk/sort (Recovery has no diff/comm).
# Run from Recovery Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/v.sh -o /Volumes/Lex4TB/v.sh && bash /Volumes/Lex4TB/v.sh

VOL="${VOL:-/Volumes/Lex4TB}"
L="$VOL/M3 Backup Oct26"
SRC="$L/source-list.txt"
BAK="$L/backup-list.txt"
MISS="$L/missing-files.txt"
LOG="$L/backup-errors.log"

for f in "$SRC" "$BAK"; do
  [ -s "$f" ] || { echo "ERROR: $f is missing or empty - re-run b.sh step 6"; exit 1; }
done
cd / || exit 1

echo "Comparing file lists (can take a few minutes)..."
awk 'NR==FNR { b[$0]; next } !($0 in b)' "$BAK" "$SRC" > "$MISS"

# Classify each missing path: regenerable/unimportant vs. worth a look.
awk -F/ '
  function junk(p) {
    return p ~ /^\.\/Library\/Caches\// || p ~ /\/\.DS_Store$/ || p ~ /^\.\/\.cache\// \
        || p ~ /^\.\/\.Trash\// || p ~ /\/node_modules\// || p ~ /\/\.venv\// || p ~ /^\.\/venv\// \
        || p ~ /^\.\/Library\/Logs\// || p ~ /^\.\/Library\/Containers\/[^\/]+\/Data\/Library\/Caches\//
  }
  { total++
    if (junk($0)) { j++; next }
    k = $2; if (NF > 3) k = k "/" $3; if (k ~ /^Library\/(Application Support|Containers|Group Containers)$/ && NF > 4) k = k "/" $4
    c[k]++; real++ }
  END {
    printf "Missing from backup:     %d\n", total
    printf "  caches/temporary/logs: %d (safe to ignore)\n", j
    printf "  everything else:       %d\n", real
    for (k in c) printf "%8d  %s\n", c[k], k
  }' "$MISS" > "$L/missing-summary.txt"

head -3 "$L/missing-summary.txt"
if [ "$(wc -l < "$L/missing-summary.txt")" -gt 3 ]; then
  echo
  echo "Everything else, by folder (count  folder):"
  sed -n '4,$p' "$L/missing-summary.txt" | sort -rn | head -25
fi

if [ -s "$LOG" ]; then
  echo
  echo "Copy errors by type (count  message):"
  awk '!/^--- / { n = split($0, a, ": "); m = a[n]; sub(/[ \t]+$/, "", m); e[m]++ }
       END { for (m in e) printf "%8d  %s\n", e[m], m }' "$LOG" | sort -rn | head -10
fi

echo
echo "Full list of missing files: $MISS"
echo "Take a photo of this screen and send it to Claude."
