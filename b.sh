#!/bin/bash
# Finish backing up the M3's user data to the Lexar drive from macOS Recovery.
# Run from Recovery Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/b.sh -o /tmp/b.sh && bash /tmp/b.sh
#
# Copies (ditto overwrites, nothing is deleted):
#   1. hidden files in the home folder (.ssh, .zshrc, ...)
#   2. Library, minus Application Support (already copied)
#   3. Application Support, minus com.apple.container (the 550 GB container disk, already copied)
#   4. /Users/Shared
# Then writes installed-apps.txt and a missing-files report to the backup folder.
# The top-level home folders (Documents, Desktop, ...) are NOT re-copied here.

DATA="${DATA:-/Volumes/Macintosh HD - Data}"
VOL="${VOL:-/Volumes/Lex4TB}"
USERNAME="${USERNAME_OVERRIDE:-Voyager1}"

S="$DATA/Users/$USERNAME"
L="$VOL/M3 Backup Oct26"
B="$L/$USERNAME"
LOG="$L/backup-errors.log"

say() { printf '\n=== %s ===\n' "$1"; }

# --- Checks -----------------------------------------------------------------
if [ ! -d "$DATA/Users" ]; then
  say "Unlocking Macintosh HD - Data (enter your Voyager1 password)"
  diskutil apfs unlockVolume "Macintosh HD - Data"
fi
if [ ! -d "$S" ]; then
  echo "ERROR: can't find $S"
  echo "Is the Data volume unlocked? Run: ls \"$DATA/Users\""
  exit 1
fi
if [ ! -d "$VOL" ]; then
  echo "ERROR: Lexar drive not found at $VOL"
  echo "Plug it in and check the name with: ls /Volumes"
  exit 1
fi
mkdir -p "$B/Library/Application Support"

echo "From: $S"
echo "To:   $B"
df -h "$VOL"
echo "Errors (normally harmless protected files) go to: $LOG"
echo "--- run started $(date) ---" >> "$LOG"

copy() { # copy <src> <dest> <label>
  echo "== $3"
  ditto "$1" "$2" 2>>"$LOG"
}

# --- 1. Hidden files ----------------------------------------------------------
say "1/6 Hidden settings files (.ssh, .zshrc ...)"
for f in "$S"/.[!.]*; do
  [ -e "$f" ] || continue
  n="${f##*/}"
  [ "$n" = ".Trash" ] && continue
  copy "$f" "$B/$n" "$n"
done

# --- 2. Library (except Application Support) ---------------------------------
say "2/6 Library (skipping Application Support)"
for f in "$S/Library"/*; do
  [ -e "$f" ] || continue
  n="${f##*/}"
  [ "$n" = "Application Support" ] && continue
  copy "$f" "$B/Library/$n" "Library/$n"
done

# --- 3. Application Support (except com.apple.container) ---------------------
say "3/6 Application Support (skipping com.apple.container)"
for f in "$S/Library/Application Support"/*; do
  [ -e "$f" ] || continue
  n="${f##*/}"
  [ "$n" = "com.apple.container" ] && continue
  copy "$f" "$B/Library/Application Support/$n" "Application Support/$n"
done

# --- 4. Shared ----------------------------------------------------------------
say "4/6 /Users/Shared"
copy "$DATA/Users/Shared" "$L/Shared" "Shared"

# --- 5. Installed apps list ---------------------------------------------------
say "5/6 Writing installed-apps.txt"
A="$DATA/Applications"
{
  echo "== Applications =="
  for a in "$A"/*.app "$A"/*/*.app; do
    [ -e "$a" ] || continue
    v=$(defaults read "$a/Contents/Info" CFBundleShortVersionString 2>/dev/null)
    s=""
    [ -d "$a/Contents/_MASReceipt" ] && s="  [App Store]"
    echo "${a#$A/}  $v$s"
  done
  echo
  echo "== Your own Applications folder =="
  ls "$S/Applications" 2>/dev/null
  echo
  echo "== Homebrew apps =="
  ls "$DATA/opt/homebrew/Caskroom" 2>/dev/null
  echo
  echo "== Homebrew tools =="
  ls "$DATA/opt/homebrew/Cellar" 2>/dev/null
} > "$L/installed-apps.txt"
echo "$(grep -c '\.app' "$L/installed-apps.txt") apps listed"

# --- 6. Verify ----------------------------------------------------------------
say "6/6 Checking for missing files (takes a few minutes)"
( cd "$S" && find . -type f 2>/dev/null | sort ) > "$L/source-list.txt"
( cd "$B" && find . -type f 2>/dev/null | sort ) > "$L/backup-list.txt"
# Recovery has no diff/comm, so compare with awk.
awk 'NR==FNR { b[$0]; next } !($0 in b)' "$L/backup-list.txt" "$L/source-list.txt" \
  | grep -v -e '^\./Library/Caches/' -e '/\.DS_Store$' > "$L/missing-files.txt"

src=$(wc -l < "$L/source-list.txt" | tr -d ' ')
bak=$(wc -l < "$L/backup-list.txt" | tr -d ' ')
mis=$(wc -l < "$L/missing-files.txt" | tr -d ' ')
errs=$(grep -vc '^--- run started' "$LOG")

say "DONE"
echo "Files on Mac:        $src"
echo "Files in backup:     $bak"
echo "Missing from backup: $mis (caches and .DS_Store ignored)"
echo "Copy errors logged:  $errs"
df -h "$VOL"
if [ "$mis" -gt 0 ]; then
  echo
  echo "Missing, by top-level folder:"
  cut -d/ -f2 "$L/missing-files.txt" | sort | uniq -c | sort -rn | head -15
fi
echo
echo "Reports saved in: $L"
echo "  installed-apps.txt  missing-files.txt  backup-errors.log"
echo "Take a photo of this screen and send it to Claude."
