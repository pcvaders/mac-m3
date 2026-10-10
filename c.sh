#!/bin/bash
# Disable Apple's `container` tool data and its login services, to test whether
# they cause the M3's login/restart loop. Reversible: nothing is deleted.
# Run from Recovery Terminal (after b.sh has finished):
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/c.sh -o /tmp/c.sh && bash /tmp/c.sh
# Undo (Recovery clears /tmp on restart, so download again):
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/c.sh -o /tmp/c.sh && bash /tmp/c.sh undo

DATA="${DATA:-/Volumes/Macintosh HD - Data}"
VOL="${VOL:-/Volumes/Lex4TB}"
USERNAME="${USERNAME_OVERRIDE:-Voyager1}"

S="$DATA/Users/$USERNAME"
AS="$S/Library/Application Support"
C="$AS/com.apple.container"
OFF="$AS/com.apple.container.disabled"
Q="$DATA/Users/Shared/disabled-launch-items"
BK="$VOL/M3 Backup Oct26/$USERNAME/Library/Application Support/com.apple.container"

if [ ! -d "$DATA/Users" ]; then
  echo "Unlocking Macintosh HD - Data (enter your Voyager1 password)"
  diskutil apfs unlockVolume "Macintosh HD - Data"
fi
[ -d "$S" ] || { echo "ERROR: can't find $S"; exit 1; }

# --- Undo -------------------------------------------------------------------
if [ "$1" = "undo" ]; then
  [ -d "$OFF" ] && mv "$OFF" "$C" && echo "Restored com.apple.container"
  if [ -f "$Q/moved.txt" ]; then
    while IFS='|' read -r from to; do
      [ -e "$to" ] && mv "$to" "$from" && echo "Restored $from"
    done < "$Q/moved.txt"
    rm -f "$Q/moved.txt"
  fi
  echo "Undo complete. Type: reboot"
  exit 0
fi

# --- 1. Check the backup copy exists first ----------------------------------
echo "=== 1/3 Checking the container is backed up ==="
if [ -d "$BK/snapshots" ] && [ -n "$(find "$BK/snapshots" -type f -name snapshot -size +1000000k 2>/dev/null)" ]; then
  echo "OK: backup copy found on the Lexar"
elif [ -d "$OFF" ]; then
  echo "Already disabled earlier, continuing"
else
  echo "STOP: no backup of com.apple.container found at:"
  echo "  $BK"
  echo "Nothing was changed. Send a photo of this to Claude."
  exit 1
fi

# --- 2. Disable the container data ------------------------------------------
echo
echo "=== 2/3 Disabling com.apple.container ==="
if [ -d "$C" ]; then
  mv "$C" "$OFF" && echo "Renamed to com.apple.container.disabled"
else
  echo "Not present (already disabled?)"
fi

# --- 3. Disable container-related launch items ------------------------------
echo
echo "=== 3/3 Container-related launch items ==="
mkdir -p "$Q"
found=0
for dir in "$S/Library/LaunchAgents" "$DATA/Library/LaunchAgents" "$DATA/Library/LaunchDaemons"; do
  [ -d "$dir" ] || continue
  for p in "$dir"/*.plist; do
    [ -e "$p" ] || continue
    if grep -qi -e 'com.apple.container' -e 'container-apiserver' -e '/container system' "$p" 2>/dev/null \
       || case "${p##*/}" in *container*) true;; *) false;; esac; then
      dest="$Q/${p##*/}"
      mv "$p" "$dest" && echo "$p|$dest" >> "$Q/moved.txt" && echo "Moved: $p"
      found=1
    fi
  done
done
[ "$found" = 0 ] && echo "None found"

echo
echo "=== All launch items still active (for Claude to review) ==="
for dir in "$S/Library/LaunchAgents" "$DATA/Library/LaunchAgents" "$DATA/Library/LaunchDaemons"; do
  echo "-- $dir"
  ls "$dir" 2>/dev/null
done

echo
echo "DONE. Nothing was deleted. Take a photo of this screen, then type: reboot"
echo "To undo later, in Recovery Terminal:"
echo "  curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/c.sh -o /tmp/c.sh && bash /tmp/c.sh undo"
