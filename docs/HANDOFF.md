# Handoff: MacBook M3 restore (continue on the Mac itself)

Read `docs/MacBook-M3.md` in this repo for the full case history. This file is the short version, so the next session can pick up where the last one left off.

## Current state (11 Oct 2026)

- The M3 MacBook Pro is **working** on **macOS 27.0.1 (public)**. It was erased, Tahoe 26.7.1 was installed from Recovery, then it was upgraded. Login works.
- The original problem was a login/restart loop on the **macOS 27.2 developer beta**: a WindowServer watchdog panic, "initialization not complete (post IOKitWaitQuiet)", in the Display Coprocessor code. The root cause is unproven: either the beta itself, or third-party system software on the old disk.
- The new user account is deliberately **not signed in to an Apple ID** yet, so iCloud is off.
- **Beta Updates must stay Off.**
- The full backup is on the external **Lexar 4 TB** at `/Volumes/Lex4TB/M3 Backup Oct26/`:
  - `Voyager1/`: the old home folder
  - `Shared/`
  - `installed-apps.txt` (393 apps)
  - diagnostics and verification files
  - cloud-only files (Google Drive, OneDrive, Proton Drive, iCloud Drive) were not copied, because they live in the cloud

## Plan: restore in stages, testing login after each

The goal is to get everything back **and** find out what, if anything, brings the loop back. After each stage: **restart, log in, confirm the desktop loads.**

0. **Account.** Create an admin user with Account name **`voyager1`** (the old short name, lowercase), so hard-coded `/Users/voyager1` paths in dotfiles, project configs and Syncthing keep working. Do all later stages logged in as `voyager1`. Sign in to the Apple ID only in this account, which brings back iCloud Keychain. The old local keychain is at `Library/Keychains/login.keychain-db` in the backup and unlocks with the old login password. Delete the temporary setup account at the end.
1. **Files.** Run `x.sh` (below) while logged in as `voyager1`. It copies every top-level item except `Library`, plus `.ssh`, `.gitconfig` and the shell profiles. It skips caches and other dotfiles.
2. **Apps without system components:** reinstall from `installed-apps.txt`, in batches.
3. **Apps with system components, one at a time with a restart after each.** These are the main suspects:
   - Background Music (BGM audio driver)
   - NewTek NDI virtual camera
   - Little Snitch
   - EaseUS NTFS
   - Docker
   - CleverFiles / Disk Drill
   - SAT SMART driver
   - (also: Arturia, XLN, Adobe and Microsoft helpers)
4. **App data from the old `~/Library`, selectively, per app.** Never restore the whole of `Library`, `LaunchAgents`/`LaunchDaemons`, or `Preferences/ByHost`. Restore Syncthing's folder (`Library/Application Support/Syncthing`) with Syncthing stopped, so the device keeps its ID.
5. **Sign in to your Apple ID last,** as its own stage.

If the loop returns, the last thing added is the cause. Boot Recovery, remove it, and record it in `docs/MacBook-M3.md`.

### Restore command (stage 1)

```
curl -fsSL https://raw.githubusercontent.com/pcvaders/mac-m3/backup/x.sh -o ~/x.sh && bash ~/x.sh
```

It lists what it will copy and waits for you to type `yes`. If macOS asks for access to the removable volume, allow it. Errors go to `~/restore-log.txt`.

## Cautions

- **Photos, Notes and similar libraries** were last opened on the 27.2 beta. They may need upgrading or may refuse to open on 27.0.1. Keep the Lexar copy untouched until they're confirmed working.
- `Library/Application Support/com.apple.container` is a 550 GB sparse VM disk from Apple's `container` tool. Only restore it if that container is needed.
- The Home Assistant group container has pipe (FIFO) files that hang `ditto`. Skip them.
- A file in Google Drive's Obsidian vault is named after a Telegram BotFather message (MarsVoyagerBot). If that token was ever shared, revoke it with @BotFather.

## Housekeeping

- Delete the temporary `helper` admin account. It was created on the old disk, so it was probably wiped by the erase anyway.
- Set the GitHub repo `pcvaders/mac-m3` back to **private** once you no longer need the scripts over raw URLs. Also consider making `pcvaders/context` private, because it contains `wiki-personal/`.
- Add `docs/MacBook-M3.md` to NotebookLM ("Apple Diagnostics" → source "MacBook M3"), and mirror the repo to Forgejo, which is reachable from the local Mac.
- Report the beta bug in Feedback Assistant and attach `diagnostics-*.txt` from the Lexar.
- Obsidian vault ("HomeLab brain") on Google Drive, and Syncthing/Möbius: both are readable locally on the Mac, with no connectors needed.

## Scripts in this repo (branch `backup`)

| Script | Where | Purpose |
|---|---|---|
| `x.sh` | normal macOS | Stage 1 restore of files from the Lexar |
| `b.sh`, `r.sh`, `v.sh` | Recovery | Make, top up and verify the backup (done) |
| `d.sh`, `s.sh` | Recovery | Diagnostics and crash analysis (done) |
| `w.sh`, `c.sh` | Recovery | Reversible display-prefs / container disable (not needed now) |
