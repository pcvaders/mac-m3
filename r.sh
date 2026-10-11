#!/bin/bash
# Re-copy the folders the first backup missed, then re-check the backup.
# Run from Recovery Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/r.sh -o /Volumes/Lex4TB/r.sh && bash /Volumes/Lex4TB/r.sh
#
# - Library/Group Containers, one app at a time, skipping Home Assistant
#   (its pipe files make ditto hang forever)
# - Application Support/Digiarty and Application Support/Blender
# - then rebuilds backup-list.txt and runs v.sh to show what is still missing

DATA="${DATA:-/Volumes/Macintosh HD - Data}"
VOL="${VOL:-/Volumes/Lex4TB}"
USERNAME="${USERNAME_OVERRIDE:-Voyager1}"

S="$DATA/Users/$USERNAME"
L="$VOL/M3 Backup Oct26"
B="$L/$USERNAME"
LOG="$L/backup-errors.log"

if [ ! -d "$DATA/Users" ]; then
  echo "Unlocking Macintosh HD - Data (enter your Voyager1 password)"
  diskutil apfs unlockVolume "Macintosh HD - Data"
fi
[ -d "$S" ] || { echo "ERROR: can't find $S"; exit 1; }
[ -d "$B" ] || { echo "ERROR: backup folder not found at $B - is the Lexar plugged in?"; exit 1; }
cd / || exit 1
echo "--- recopy run started $(date) ---" >> "$LOG"

echo "=== 1/3 Group Containers (skipping Home Assistant) ==="
mkdir -p "$B/Library/Group Containers"
for f in "$S/Library/Group Containers"/*; do
  [ -e "$f" ] || continue
  n="${f##*/}"
  case "$n" in *homeassistant*) continue;; esac
  echo "== $n"
  ditto "$f" "$B/Library/Group Containers/$n" 2>>"$LOG"
done

echo
echo "=== 2/3 Digiarty and Blender ==="
for n in Digiarty Blender; do
  f="$S/Library/Application Support/$n"
  [ -e "$f" ] || continue
  echo "== $n"
  ditto "$f" "$B/Library/Application Support/$n" 2>>"$LOG"
done

echo
echo "=== 3/3 Re-checking the backup (takes a few minutes) ==="
( cd "$B" && find . -type f 2>/dev/null | sort ) > "$L/backup-list.txt"
if [ ! -f "$VOL/v.sh" ]; then
  curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/v.sh -o "$VOL/v.sh"
fi
bash "$VOL/v.sh"
