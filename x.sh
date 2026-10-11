#!/bin/bash
# Stage 2 restore: copy your own files back from the Lexar into this account.
# Run in Terminal on the working Mac (NOT Recovery), Lexar plugged in:
#   curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/x.sh -o ~/x.sh && bash ~/x.sh
#
# Copies every top-level folder/file from the backup EXCEPT Library, plus a
# short list of safe settings files (.ssh, .gitconfig, shell profiles).
# Does NOT restore Library, apps, launch agents, drivers or caches - those
# come back later, one app at a time. Existing files with the same name are
# overwritten; nothing is deleted.

VOL="${VOL:-/Volumes/Lex4TB}"
SRC="${SRC:-$VOL/M3 Backup Oct26/Voyager1}"
DEST="${DEST:-$HOME}"
LOG="$DEST/restore-log.txt"

# Settings files worth bringing back now (everything else waits).
DOTFILES=".ssh .gitconfig .gitignore_global .zshrc .zprofile .zshenv .bash_profile .bashrc .profile"
# Top-level items that are regenerable or risky - skipped.
SKIP="Library .Trash .cache .DS_Store .CFUserTextEncoding"

[ -d "$SRC" ] || { echo "Backup not found at: $SRC"; echo "Is the Lexar plugged in? Check with: ls /Volumes"; exit 1; }

echo "Restoring from: $SRC"
echo "Into:           $DEST"
echo
echo "Will copy:"
for f in "$SRC"/*; do
  n="${f##*/}"
  case " $SKIP " in *" $n "*) continue;; esac
  echo "  $n"
done
for d in $DOTFILES; do [ -e "$SRC/$d" ] && echo "  $d"; done
echo
echo "Will NOT copy: Library, caches, other hidden folders (restored later, app by app)."
echo
if [ -t 0 ]; then
  read -r -p "Type yes to start: " ok
  [ "$ok" = "yes" ] || { echo "Cancelled - nothing copied."; exit 0; }
fi

echo "--- restore started $(date) ---" >> "$LOG"
for f in "$SRC"/*; do
  n="${f##*/}"
  case " $SKIP " in *" $n "*) continue;; esac
  echo "== $n"
  ditto "$f" "$DEST/$n" 2>>"$LOG"
done
for d in $DOTFILES; do
  [ -e "$SRC/$d" ] || continue
  echo "== $d"
  ditto "$SRC/$d" "$DEST/$d" 2>>"$LOG"
done
[ -d "$DEST/.ssh" ] && chmod 700 "$DEST/.ssh" && chmod 600 "$DEST/.ssh"/id_* 2>/dev/null

echo
echo "DONE. Errors (if any) are in: $LOG"
echo "Copy errors logged: $(grep -vc '^--- ' "$LOG")"
echo "Next: restart the Mac and check you can still log in. Then tell Claude."
