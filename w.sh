#!/bin/bash
# Test fix for the WindowServer watchdog panic at login: move the display /
# WindowServer settings files aside so macOS rebuilds them. Nothing is deleted.
# Run from Recovery Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/w.sh -o /Volumes/Lex4TB/w.sh && bash /Volumes/Lex4TB/w.sh
# Undo:
#   bash /Volumes/Lex4TB/w.sh undo

DATA="${DATA:-/Volumes/Macintosh HD - Data}"
USERNAME="${USERNAME_OVERRIDE:-Voyager1}"
S="$DATA/Users/$USERNAME"
Q="$DATA/Users/Shared/disabled-prefs"

if [ ! -d "$DATA/Users" ]; then
  echo "Unlocking Macintosh HD - Data (enter your Voyager1 password)"
  diskutil apfs unlockVolume "Macintosh HD - Data"
fi
[ -d "$S" ] || { echo "ERROR: can't find $S"; exit 1; }

if [ "$1" = "undo" ]; then
  [ -f "$Q/moved.txt" ] || { echo "Nothing to undo"; exit 0; }
  while IFS='|' read -r from to; do
    [ -e "$to" ] && mv "$to" "$from" && echo "Restored ${from#$DATA}"
  done < "$Q/moved.txt"
  rm -f "$Q/moved.txt"
  echo "Undo complete. Type: reboot"
  exit 0
fi

mkdir -p "$Q"
n=0
for f in "$DATA/Library/Preferences/"com.apple.windowserver* \
         "$S/Library/Preferences/ByHost/"com.apple.windowserver* \
         "$S/Library/Preferences/"com.apple.windowserver*; do
  [ -e "$f" ] || continue
  dest="$Q/$(echo "${f#$DATA/}" | tr '/' '_')"
  mv "$f" "$dest" && echo "$f|$dest" >> "$Q/moved.txt" && echo "Moved ${f#$DATA}" && n=$((n+1))
done

echo
if [ "$n" = 0 ]; then
  echo "No WindowServer settings files found - nothing changed."
  echo "This fix doesn't apply; the beta itself is the likely cause."
else
  echo "Moved $n file(s) to /Users/Shared/disabled-prefs (nothing deleted)."
  echo "Now type: reboot   and try logging in."
  echo "To undo later: bash /Volumes/Lex4TB/w.sh undo"
fi
